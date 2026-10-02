import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';

final class OfflineTripPackageState extends Equatable {
  const OfflineTripPackageState({
    required this.package,
    this.deviceFreeStorageMb = 14200.0, // 14.2 GB typical
    this.downloadStepDescription = '',
    this.isDemoMode = false,
  });

  final OfflineTripPackage package;
  final double deviceFreeStorageMb;
  final String downloadStepDescription;
  final bool isDemoMode;

  OfflineTripPackageState copyWith({
    OfflineTripPackage? package,
    double? deviceFreeStorageMb,
    String? downloadStepDescription,
    bool? isDemoMode,
  }) {
    return OfflineTripPackageState(
      package: package ?? this.package,
      deviceFreeStorageMb: deviceFreeStorageMb ?? this.deviceFreeStorageMb,
      downloadStepDescription:
          downloadStepDescription ?? this.downloadStepDescription,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    package,
    deviceFreeStorageMb,
    downloadStepDescription,
    isDemoMode,
  ];
}
