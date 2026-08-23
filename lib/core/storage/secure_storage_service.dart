import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorageService {
  Future<void> delete(String key);

  Future<void> deleteAll();

  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

final class FlutterSecureStorageService implements SecureStorageService {
  const FlutterSecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}
