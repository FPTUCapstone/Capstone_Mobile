import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';

final class OfflineTripPackageState extends Equatable {
  const OfflineTripPackageState({
    required this.package,
    this.replacementPackage,
    this.deviceFreeStorageMb = 14200.0, // 14.2 GB typical
    this.downloadStepDescription = '',
    this.isDemoMode = false,
  });

  /// The current installed / primary package.
  final OfflineTripPackage package;

  /// In-flight replacement download when refreshing a superseded package.
  /// Null when no replacement download is active.
  final OfflineTripPackage? replacementPackage;

  final double deviceFreeStorageMb;
  final String downloadStepDescription;
  final bool isDemoMode;

  /// True while an update replacement is actively checking storage or downloading.
  bool get isRefreshing => replacementPackage != null;

  /// True if a usable offline package is installed (available or superseded).
  bool get isAvailableOffline => package.isAvailableOffline;

  OfflineTripPackageState copyWith({
    OfflineTripPackage? package,
    OfflineTripPackage? replacementPackage,
    bool clearReplacementPackage = false,
    double? deviceFreeStorageMb,
    String? downloadStepDescription,
    bool? isDemoMode,
  }) {
    return OfflineTripPackageState(
      package: package ?? this.package,
      replacementPackage: clearReplacementPackage
          ? null
          : (replacementPackage ?? this.replacementPackage),
      deviceFreeStorageMb: deviceFreeStorageMb ?? this.deviceFreeStorageMb,
      downloadStepDescription:
          downloadStepDescription ?? this.downloadStepDescription,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    package,
    replacementPackage,
    deviceFreeStorageMb,
    downloadStepDescription,
    isDemoMode,
  ];
}
