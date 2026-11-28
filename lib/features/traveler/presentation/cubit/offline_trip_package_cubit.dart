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
                       title: title ?? 'Khám phá Đà Nẵng',
                     )
                   : OfflineTripPackage(
                       itineraryId: itineraryId,
                       title: title ?? 'Chuyến đi #$itineraryId',
                       version: version,
                       status: OfflinePackageStatus.unavailable,
                       totalSizeMb: 0.0,
                       errorMessage:
                           'Tính năng tải bản đồ và lịch trình ngoại tuyến hiện chưa khả dụng do dịch vụ gói chuyến đi và lưu trữ cục bộ chưa được kết nối.',
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
                'Tính năng tải bản đồ và lịch trình ngoại tuyến hiện chưa khả dụng do dịch vụ gói chuyến đi và lưu trữ cục bộ chưa được kết nối.',
          ),
          downloadStepDescription: 'Dịch vụ tải xuống không khả dụng.',
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
        downloadStepDescription: 'Đang kiểm tra dung lượng bộ nhớ thiết bị...',
      ),
    );

    // Validate 150 MB ceiling rule (BR-37)
    if (pkg.totalSizeMb > pkg.maxLimitMb) {
      emit(
        state.copyWith(
          package: pkg.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Dung lượng gói (${pkg.totalSizeMb.toStringAsFixed(1)} MB) vượt quá giới hạn 150 MB.',
          ),
          downloadStepDescription: 'Vượt quá giới hạn dung lượng.',
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
                'Không đủ dung lượng bộ nhớ. Cần ít nhất 150 MB trống để lưu dữ liệu ngoại tuyến.',
          ),
          downloadStepDescription: 'Thiết bị không đủ dung lượng trống.',
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
        downloadStepDescription:
            'Đang tải lịch trình và dữ liệu tuyến đường...',
      ),
    );

    emit(
      state.copyWith(
        package: state.package.copyWith(progressPercent: 55.0),
        downloadStepDescription: 'Đang tải ảnh và thông tin điểm đến...',
      ),
    );

    emit(
      state.copyWith(
        package: state.package.copyWith(progressPercent: 88.0),
        downloadStepDescription: 'Đang tải bản đồ khu vực ngoại tuyến...',
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
        downloadStepDescription: 'Gói dữ liệu ngoại tuyến đã sẵn sàng.',
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
              'Đã hủy cập nhật. Gói ngoại tuyến hiện tại vẫn được giữ lại.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.notDownloaded,
            progressPercent: 0.0,
          ),
          downloadStepDescription:
              'Đã hủy tải xuống. Dữ liệu tải dở đã được xóa.',
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
        downloadStepDescription: 'Đã xóa dữ liệu ngoại tuyến khỏi thiết bị.',
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
        downloadStepDescription:
            'Đang kiểm tra dung lượng thiết bị để cập nhật...',
      ),
    );

    // Validate 150 MB ceiling rule (BR-37)
    if (replacement.totalSizeMb > replacement.maxLimitMb) {
      emit(
        state.copyWith(
          replacementPackage: replacement.copyWith(
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage:
                'Dung lượng gói (${replacement.totalSizeMb.toStringAsFixed(1)} MB) vượt quá giới hạn 150 MB.',
          ),
          downloadStepDescription:
              'Vượt quá giới hạn dung lượng cho bản cập nhật.',
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
                'Không đủ dung lượng bộ nhớ. Cần ít nhất 150 MB trống để lưu dữ liệu ngoại tuyến.',
          ),
          downloadStepDescription:
              'Thiết bị không đủ dung lượng trống để cập nhật.',
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
            'Đang tải lịch trình và dữ liệu tuyến đường mới...',
      ),
    );

    replacement = replacement.copyWith(progressPercent: 55.0);
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription: 'Đang tải ảnh và thông tin điểm đến mới...',
      ),
    );

    replacement = replacement.copyWith(progressPercent: 88.0);
    emit(
      state.copyWith(
        replacementPackage: replacement,
        downloadStepDescription: 'Đang tải bản đồ khu vực ngoại tuyến mới...',
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
        downloadStepDescription: 'Đã cập nhật gói dữ liệu ngoại tuyến.',
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
                'Cập nhật bị gián đoạn do mất kết nối. Dữ liệu ngoại tuyến hiện có vẫn dùng được.',
          ),
          downloadStepDescription: 'Mất kết nối trong quá trình cập nhật.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            status: OfflinePackageStatus.networkInterrupted,
            errorMessage:
                'Tải xuống bị gián đoạn do mất kết nối. Dữ liệu tải dở đã được hủy bỏ.',
          ),
          downloadStepDescription: 'Kết nối bị gián đoạn.',
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
            errorMessage: 'Dung lượng gói (184.2 MB) vượt quá giới hạn 150 MB.',
          ),
          downloadStepDescription: 'Bản cập nhật vượt quá giới hạn 150 MB.',
        ),
      );
    } else {
      emit(
        state.copyWith(
          package: state.package.copyWith(
            totalSizeMb: 184.2,
            status: OfflinePackageStatus.insufficientStorage,
            errorMessage: 'Dung lượng gói (184.2 MB) vượt quá giới hạn 150 MB.',
          ),
          downloadStepDescription: 'Vượt quá giới hạn 150 MB.',
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
            'Có phiên bản lịch trình mới hơn trên máy chủ.',
      ),
    );
  }
}
