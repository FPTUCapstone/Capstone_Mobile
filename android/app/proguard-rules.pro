# Keep Pigeon / JNI bridge methods used by shared_preferences_android so R8
# release builds do not strip SharedPreferencesApiRegistrar.getAll at startup.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.flutter.pigeon.** { *; }
