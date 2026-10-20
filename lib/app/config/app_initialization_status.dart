/// Diagnostic status tracking initialization states for external platform services.
class AppInitializationStatus {
  const AppInitializationStatus({
    this.isFirebaseAvailable = false,
    this.isGoogleSignInAvailable = false,
    this.isMapboxAvailable = false,
    this.firebaseError,
    this.googleSignInError,
    this.mapboxError,
  });

  /// Whether Firebase Core was initialized successfully.
  final bool isFirebaseAvailable;

  /// Whether Google Sign-In was initialized successfully.
  final bool isGoogleSignInAvailable;

  /// Whether Mapbox SDK was configured with an access token.
  final bool isMapboxAvailable;

  /// Sanitized diagnostic error if Firebase initialization failed.
  final String? firebaseError;

  /// Sanitized diagnostic error if Google Sign-In initialization failed.
  final String? googleSignInError;

  /// Sanitized diagnostic error if Mapbox initialization failed.
  final String? mapboxError;

  /// Returns `true` if all external platform integrations succeeded.
  bool get isFullyInitialized =>
      isFirebaseAvailable && isGoogleSignInAvailable && isMapboxAvailable;

  /// Returns `true` if any optional integration is unavailable/degraded.
  bool get isDegraded => !isFullyInitialized;
}
