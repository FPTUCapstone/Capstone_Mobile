import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorageService {
  Future<void> delete(String key);

  Future<void> deleteAll();

  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

final _sessionOperations = Expando<Future<void>>();

extension SessionStorageOperations on SecureStorageService {
  /// Serializes a credential read/modify/write with login, logout and renewal.
  Future<T> withSessionLock<T>(Future<T> Function() action) async {
    final previous = _sessionOperations[this] ?? Future<void>.value();
    final completed = Completer<void>();
    _sessionOperations[this] = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
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
