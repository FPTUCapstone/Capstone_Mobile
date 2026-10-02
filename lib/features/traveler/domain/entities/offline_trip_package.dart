import 'package:equatable/equatable.dart';

enum OfflinePackageStatus {
  notDownloaded,
  checkingStorage,
  downloading,
  available,
  superseded,
  insufficientStorage,
  networkInterrupted,
  error,
}

final class OfflineTripPackage extends Equatable {
  const OfflineTripPackage({
    required this.itineraryId,
    required this.title,
    required this.version,
    this.status = OfflinePackageStatus.notDownloaded,
    required this.totalSizeMb,
    this.maxLimitMb = 150.0,
    this.progressPercent = 0.0,
    this.lastDownloadedAt,
    this.dateRange,
    this.stopsCount = 0,
    this.errorMessage,
  });

  final int itineraryId;
  final String title;
  final int version;
  final OfflinePackageStatus status;
  final double totalSizeMb;
  final double maxLimitMb;
  final double progressPercent;
  final DateTime? lastDownloadedAt;
  final String? dateRange;
  final int stopsCount;
  final String? errorMessage;

  bool get isAvailableOffline =>
      status == OfflinePackageStatus.available ||
      status == OfflinePackageStatus.superseded;
  bool get exceedsMaxLimit => totalSizeMb > maxLimitMb;

  OfflineTripPackage copyWith({
    int? itineraryId,
    String? title,
    int? version,
    OfflinePackageStatus? status,
    double? totalSizeMb,
    double? maxLimitMb,
    double? progressPercent,
    DateTime? lastDownloadedAt,
    bool clearLastDownloadedAt = false,
    String? dateRange,
    bool clearDateRange = false,
    int? stopsCount,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OfflineTripPackage(
      itineraryId: itineraryId ?? this.itineraryId,
      title: title ?? this.title,
      version: version ?? this.version,
      status: status ?? this.status,
      totalSizeMb: totalSizeMb ?? this.totalSizeMb,
      maxLimitMb: maxLimitMb ?? this.maxLimitMb,
      progressPercent: progressPercent ?? this.progressPercent,
      lastDownloadedAt: clearLastDownloadedAt
          ? null
          : (lastDownloadedAt ?? this.lastDownloadedAt),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      stopsCount: stopsCount ?? this.stopsCount,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    itineraryId,
    title,
    version,
    status,
    totalSizeMb,
    maxLimitMb,
    progressPercent,
    lastDownloadedAt,
    dateRange,
    stopsCount,
    errorMessage,
  ];
}
