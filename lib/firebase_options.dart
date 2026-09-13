import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (const bool.fromEnvironment('dart.library.io')) {
      return android;
    }

    throw UnsupportedError(
      'TripMate Firebase is configured for Android only.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwyWeN7JqF9gL8EtNs7Ce9RX5J4uFmLz0',
    appId: '1:105500206516:android:501b63e433d96813d57ee1',
    messagingSenderId: '105500206516',
    projectId: 'tripmate-82be3',
    storageBucket: 'tripmate-82be3.firebasestorage.app',
  );
}