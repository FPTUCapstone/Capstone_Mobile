import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';

abstract interface class GroupLocationRepository {
  Future<List<int>> getEnabledGroupIds();
  Future<LocationSharingSetting> getSetting(int groupId);
  Future<LocationSharingSetting> updateSetting(int groupId, bool enabled);
  Future<List<GroupLocation>> getLocations(int groupId);
  Future<void> publish(
    int groupId,
    DeviceGroupLocation location,
    String sessionVersion,
  );
  Future<void> clear(int groupId);
}
