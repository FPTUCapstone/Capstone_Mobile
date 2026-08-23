import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
  });

  tearDown(() => serviceLocator.reset());

  testWidgets('bootstraps and routes to the Traveler shell through Cubit', (
    tester,
  ) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    expect(find.text('Plan smarter. Travel better.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a mobile experience'), findsOneWidget);

    await tester.tap(find.text('Preview Traveler shell'));
    await tester.pumpAndSettle();
    expect(find.text('Traveler · Home'), findsOneWidget);
    expect(find.text('Traveler Home'), findsOneWidget);
  });
}
