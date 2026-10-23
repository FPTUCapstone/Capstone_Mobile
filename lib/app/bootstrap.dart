import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/app_initialization_status.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/firebase_options.dart';

Future<AppInitializationStatus> bootstrap({
  AppConfig? config,
  bool launchApp = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  var isFirebaseAvailable = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseAvailable = true;
  } catch (e) {
    firebaseError = 'Firebase initialization unavailable: ${e.runtimeType}';
    debugPrint('[Bootstrap] $firebaseError');
  }

  var isGoogleSignInAvailable = false;
  String? googleSignInError;
  try {
    await GoogleSignIn.instance.initialize();
    isGoogleSignInAvailable = true;
  } catch (e) {
    googleSignInError = 'GoogleSignIn unavailable: ${e.runtimeType}';
    debugPrint('[Bootstrap] $googleSignInError');
  }

  await configureDependencies(config: config);

  var isMapboxAvailable = false;
  String? mapboxError;
  final mapboxAccessToken = serviceLocator<AppConfig>().mapboxAccessToken;
  if (mapboxAccessToken != null && mapboxAccessToken.isNotEmpty) {
    try {
      MapboxOptions.setAccessToken(mapboxAccessToken);
      isMapboxAvailable = true;
    } catch (e) {
      mapboxError = 'Mapbox token configuration unavailable: ${e.runtimeType}';
      debugPrint('[Bootstrap] $mapboxError');
    }
  }

  final status = AppInitializationStatus(
    isFirebaseAvailable: isFirebaseAvailable,
    isGoogleSignInAvailable: isGoogleSignInAvailable,
    isMapboxAvailable: isMapboxAvailable,
    firebaseError: firebaseError,
    googleSignInError: googleSignInError,
    mapboxError: mapboxError,
  );

  if (serviceLocator.isRegistered<AppInitializationStatus>()) {
    await serviceLocator.unregister<AppInitializationStatus>();
  }
  serviceLocator.registerSingleton<AppInitializationStatus>(status);

  if (launchApp) {
    runApp(const TripMateApp());
  }

  return status;
}
