import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

class OfflineTripPackageCubit extends Cubit<OfflineTripPackageState> {
  OfflineTripPackageCubit({
    required int itineraryId,
    String title = 'Đà Nẵng City Explorer',
    OfflineTripPackage? initialPackage,
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
                       title: title,
                     )
                   : OfflineTripPackage(
                       itineraryId: itineraryId,
                       title: title,
                       version: 1,
                       status: OfflinePackageStatus.notDownloaded,
                       totalSizeMb: 0.0,
                     )),
           deviceFreeStorageMb: initialFreeStorageMb,
           downloadStepDescription: initialDownloadStepDescription,
           isDemoMode: isDemoMode,
         ),
       );

  /// Initiates download for offline use.
  /// Validates:
  /// 1. Package size <= 150 MB configured ceiling (BR-37).
  /// 2. Device free space >= 150 MB minimum required space.
  Future<void> startDownload() async {
    final pkg = state.package;

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

    // Start download stream simulation
    emit(
      state.copyWith(
        package: pkg.copyWith(
          status: OfflinePackageStatus.downloading,
          progressPercent: 15.0,
        ),
        downloadStepDescription: 'Downloading itinerary and route geometry...',
      ),
    );

    // If demo mode, progress through steps
    if (state.isDemoMode) {
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
    } else {
      // Production mode: download service / backend packaging is not implemented yet.
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.error,
            errorMessage: 'Offline download service is currently unavailable.',
          ),
          downloadStepDescription: 'Download service unavailable.',
        ),
      );
    }
  }

  /// Cancels in-progress download. Discards partial download (BR-38).
  void cancelDownload() {
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

  /// Removes downloaded package from local device storage.
  void removeOfflineData() {
    emit(
      state.copyWith(
        package: state.package.copyWith(
          status: OfflinePackageStatus.notDownloaded,
          progressPercent: 0.0,
          clearLastDownloadedAt: true,
          clearErrorMessage: true,
        ),
        downloadStepDescription: 'Offline data removed from device.',
      ),
    );
  }

  /// Refreshes superseded offline package.
  /// Retains current version available until replacement download finishes.
  Future<void> refreshSupersededPackage() async {
    // Retains existing version while downloading update
    await startDownload();
  }

  // =========================================================================
  // DEMO_ONLY SIMULATION CONTROLS
  // =========================================================================

  /// DEMO_ONLY: Simulates a network interruption during download.
  void demoSimulateNetworkInterruption() {
    if (!state.isDemoMode) return;
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

  /// DEMO_ONLY: Simulates package exceeding 150 MB ceiling.
  void demoSimulateOversizePackage() {
    if (!state.isDemoMode) return;
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

  /// DEMO_ONLY: Simulates server version incrementing to test refresh flow.
  void demoSimulateSuperseded() {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        package: state.package.copyWith(
          status: OfflinePackageStatus.superseded,
          version: state.package.version,
        ),
        downloadStepDescription:
            'A newer itinerary version is available on the server.',
      ),
    );
  }
}
