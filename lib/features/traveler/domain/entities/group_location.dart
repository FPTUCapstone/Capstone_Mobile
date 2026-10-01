import 'package:equatable/equatable.dart';

final class DeviceGroupLocation extends Equatable {
  const DeviceGroupLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [latitude, longitude];
}

final class GroupLocation extends Equatable {
  const GroupLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.recordedAtUtc,
  });

  final int userId;
  final double latitude;
  final double longitude;
  final DateTime recordedAtUtc;

  @override
  List<Object> get props => [userId, latitude, longitude, recordedAtUtc];
}

final class LocationSharingSetting extends Equatable {
  const LocationSharingSetting({
    required this.groupId,
    required this.enabled,
    this.updatedAtUtc,
    this.sessionVersion,
  });

  final int groupId;
  final bool enabled;
  final DateTime? updatedAtUtc;
  final String? sessionVersion;

  @override
  List<Object?> get props => [groupId, enabled, updatedAtUtc, sessionVersion];
}
