import 'package:flutter/widgets.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';

Future<void> bootstrap({AppConfig? config}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(config: config);
  runApp(const TripMateApp());
}
