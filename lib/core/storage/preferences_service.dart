import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesService {
  bool? getBool(String key);

  String? getString(String key);

  Future<bool> remove(String key);

  Future<bool> setBool(String key, bool value);

  Future<bool> setString(String key, String value);
}

final class SharedPreferencesService implements PreferencesService {
  const SharedPreferencesService(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool? getBool(String key) => _preferences.getBool(key);

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);

  @override
  Future<bool> setBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }

  @override
  Future<bool> setString(String key, String value) {
    return _preferences.setString(key, value);
  }
}
