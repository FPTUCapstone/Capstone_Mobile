import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/offline_access_identity.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_map_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => serviceLocator.reset());
  test(
    'offline graph resolves without performing native or network I/O',
    () async {
      SharedPreferences.setMockInitialValues({});
      await serviceLocator.reset();
      await configureDependencies(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
      );
      expect(serviceLocator<OfflineAccessIdentity>(), isNotNull);
      expect(serviceLocator<OfflineMapDataSource>(), isNotNull);
      expect(serviceLocator<OfflineTripRepository>(), isNotNull);
    },
  );
}
