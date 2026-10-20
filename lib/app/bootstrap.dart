import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/firebase_options.dart';

Future<void> bootstrap({AppConfig? config}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization skipped or failed: $e');
  }
  try {
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    debugPrint('GoogleSignIn initialization skipped: $e');
  }
  await configureDependencies(config: config);
  final mapboxAccessToken = serviceLocator<AppConfig>().mapboxAccessToken;
  if (mapboxAccessToken != null) {
    try {
      MapboxOptions.setAccessToken(mapboxAccessToken);
    } catch (e) {
      debugPrint('Mapbox setAccessToken skipped: $e');
    }
  }
  runApp(const TripMateApp());
}
