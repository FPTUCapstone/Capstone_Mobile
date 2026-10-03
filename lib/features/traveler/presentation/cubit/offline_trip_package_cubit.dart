import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

class OfflineTripPackageCubit extends Cubit<OfflineTripPackageState> {
  OfflineTripPackageCubit({
    required int itineraryId,
    String? title,
    int version = 1,
    OfflineTripPackage? initialPackage,
    OfflineTripPackage? initialReplacementPackage,
    double initialFreeStorageMb = 14200.0,
    String initialDownloadStepDescription = '',
    bool isDemoMode = false,
  }) : super(
         OfflineTripPackageState(
           package:
               initialPackage ??
               (isDemoMode
                   ? ActiveTripDemoFixtures.createSampleOfflinePackage(
                       itineraryId: itineraryId,
                       title: title ?? 'Đà Nẵng City Explorer',
                     )
                   : OfflineTripPackage(
                       itineraryId: itineraryId,
                       title: title ?? 'Trip #$itineraryId',
                       version: version,
                       status: OfflinePackageStatus.unavailable,
                       totalSizeMb: 0.0,
                       errorMessage:
                           'Offline map and itinerary download is not currently available because the required trip-package service and local persistence integration are not yet connected.',
                     )),
           replacementPackage: initialReplacementPackage,
           deviceFreeStorageMb: isDemoMode ? initialFreeStorageMb : 0.0,
           downloadStepDescription: initialDownloadStepDescription,
           isDemoMode: isDemoMode,
         ),
       );

  /// Initiates download for offline use.
  /// Validates:
  /// 1. Package size <= 150 MB configured ceiling (BR-37).
  /// 2. Device free space >= 150 MB minimum required space.
  Future<void> startDownload() async {
    if (!state.isDemoMode) {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.unavailable,
            errorMessage:
                'Offline map and itinerary download is not currently available because the required trip-package service and local persistence integration are not yet connected.',
          ),
          downloadStepDescription: 'Download service unavailable.',
        ),
      );
      return;
    }

    final pkg = state.package;

    // If package is already installed and superseded, route to refresh to preserve usable copy
    if (pkg.status == OfflinePackageStatus.superseded) {
      await refreshSupersededPackage();
      return;
    }

    // Transition to checking storage
    emit(
      state.copyWith(
        package: pkg.copyWith(status: OfflinePackageStatus.checkingStorage),
        downloadStepDescription: 'Checking device storage space...',
      ),
    );

    // Validate 150 MB ceiling rule (BR-37)
    if (pkg.totalSizeMb > pkg.maxLimitMb) {
      emit(
        state.copyWith(
          package: pkg.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Package size (${pkg.totalSizeMb.toStringAsFixed(1)} MB) exceeds configured limit of 150 MB.',
          ),
          downloadStepDescription: 'Storage limit exceeded.',
        ),
      );
      return;
    }

    // Validate available device storage
    if (state.deviceFreeStorageMb < 150.0) {
      emit(
        state.copyWith(
          package: pkg.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Insufficient storage space. At least 150MB free space required for offline data.',
          ),
          downloadStepDescription: 'Insufficient free space on device.',
        ),
      );
      return;
    }

    // Start download stream simulation (DEMO ONLY)
    emit(
      state.copyWith(
        package: pkg.copyWith(
          status: OfflinePackageStatus.downloading,
          progressPercent: 15.0,
        ),
        downloadStepDescription: 'Downloading itinerary and route geometry...',
      ),
    );

    emit(
      state.copyWith(
        package: state.package.copyWith(progressPercent: 55.0),
        downloadStepDescription: 'Downloading POI photos & information...',
      ),
    );

    emit(
      state.copyWith(
        package: state.package.copyWith(progressPercent: 88.0),
        downloadStepDescription: 'Downloading offline area map tiles...',
      ),
    );

    // Successfully stored (BR-38)
    emit(
      state.copyWith(
        package: state.package.copyWith(
          status: OfflinePackageStatus.available,
          progressPercent: 100.0,
          lastDownloadedAt: DateTime.now(),
        ),
        downloadStepDescription: 'Offline package ready.',
      ),
    );
  }

  /// Cancels in-progress download. Discards partial download (BR-38).
  /// If a replacement download was in progress, discards replacement while keeping installed package intact.
  void cancelDownload() {
    if (!state.isDemoMode) return;
    if (state.replacementPackage != null) {
      emit(
        state.copyWith(
          clearReplacementPackage: true,
          downloadStepDescription:
              'Update cancelled. Current offline package retained.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.notDownloaded,
            progressPercent: 0.0,
          ),
          downloadStepDescription: 'Download cancelled. Partial data removed.',
        ),
      );
    }
  }

  /// Removes downloaded package from local device storage.
  /// Also cancels and discards any active replacement download.
  void removeOfflineData() {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        package: state.package.copyWith(
          status: OfflinePackageStatus.notDownloaded,
          progressPercent: 0.0,
          clearLastDownloadedAt: true,
          clearErrorMessage: true,
        ),
        clearReplacementPackage: true,
        downloadStepDescription: 'Offline data removed from device.',
      ),
    );
  }

  /// Refreshes superseded offline package.
  /// Retains current version available and usable until replacement download finishes.
  Future<void> refreshSupersededPackage() async {
    if (!state.isDemoMode) return;

    final currentPkg = state.package;
    final targetVersion = currentPkg.version + 1;
    var replacement = OfflineTripPackage(
      itineraryId: currentPkg.itineraryId,
      title: currentPkg.title,
      version: targetVersion,
      status: OfflinePackageStatus.checkingStorage,
      totalSizeMb: currentPkg.totalSizeMb,
      maxLimitMb: currentPkg.maxLimitMb,
      dateRange: currentPkg.dateRange,
      stopsCount: currentPkg.stopsCount,
      progressPercent: 0.0,
    );

    // Transition replacement to checking storage while CURRENT package stays intact
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription: 'Checking device storage space for update...',
      ),
    );

    // Validate 150 MB ceiling rule (BR-37)
    if (replacement.totalSizeMb > replacement.maxLimitMb) {
      emit(
        state.copyWith(
          replacementPackage: replacement.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Package size (${replacement.totalSizeMb.toStringAsFixed(1)} MB) exceeds configured limit of 150 MB.',
          ),
          downloadStepDescription: 'Storage limit exceeded for update.',
        ),
      );
      return;
    }

    // Validate available device storage
    if (state.deviceFreeStorageMb < 150.0) {
      emit(
        state.copyWith(
          replacementPackage: replacement.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Insufficient storage space. At least 150MB free space required for offline data.',
          ),
          downloadStepDescription:
              'Insufficient free space on device for update.',
        ),
      );
      return;
    }

    // Start replacement download stream simulation (CURRENT package remains available)
    replacement = replacement.copyWith(
      status: OfflinePackageStatus.downloading,
      progressPercent: 15.0,
    );
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription:
            'Downloading updated itinerary and route geometry...',
      ),
    );

    replacement = replacement.copyWith(progressPercent: 55.0);
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription:
            'Downloading updated POI photos & information...',
      ),
    );

    replacement = replacement.copyWith(progressPercent: 88.0);
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription:
            'Downloading updated offline area map tiles...',
      ),
    );

    // Successfully stored (BR-38): atomically promote replacement to current installed package
    emit(
      state.copyWith(
        package: replacement.copyWith(
          status: OfflinePackageStatus.available,
          progressPercent: 100.0,
          lastDownloadedAt: DateTime.now(),
        ),
        clearReplacementPackage: true,
        downloadStepDescription: 'Offline package updated.',
      ),
    );
  }

  // =========================================================================
  // DEMO_ONLY SIMULATION CONTROLS
  // =========================================================================

  /// DEMO_ONLY: Simulates a network interruption during download.
  void demoSimulateNetworkInterruption() {
    if (!state.isDemoMode) return;
    if (state.replacementPackage != null) {
      emit(
        state.copyWith(
          replacementPackage: state.replacementPackage!.copyWith(
            status: OfflinePackageStatus.networkInterrupted,
            errorMessage:
                'Update interrupted due to connection loss. Existing offline data remains usable.',
          ),
          downloadStepDescription: 'Connection interrupted during update.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.networkInterrupted,
            errorMessage:
                'Download interrupted due to connection loss. Partial download discarded.',
          ),
          downloadStepDescription: 'Connection interrupted.',
        ),
      );
    }
  }

  /// DEMO_ONLY: Simulates package exceeding 150 MB ceiling.
  void demoSimulateOversizePackage() {
    if (!state.isDemoMode) return;
    if (state.replacementPackage != null) {
      emit(
        state.copyWith(
          replacementPackage: state.replacementPackage!.copyWith(
            totalSizeMb: 184.2,
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Package size (184.2 MB) exceeds configured limit of 150 MB.',
          ),
          downloadStepDescription:
              'Configured limit of 150 MB exceeded for update.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            totalSizeMb: 184.2,
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Package size (184.2 MB) exceeds configured limit of 150 MB.',
          ),
          downloadStepDescription: 'Configured limit of 150 MB exceeded.',
        ),
      );
    }
  }

  /// DEMO_ONLY: Simulates server version incrementing to test refresh flow.
  void demoSimulateSuperseded() {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        package: state.package.copyWith(
          status: OfflinePackageStatus.superseded,
          version: state.package.version,
        ),
        clearReplacementPackage: true,
        downloadStepDescription:
            'A newer itinerary version is available on the server.',
      ),
    );
  }
}
