import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/offline_trip_manifest_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';

final class OfflineStorageLimitException implements Exception {
  const OfflineStorageLimitException();
}

final class OfflineDataCorruptException implements Exception {
  const OfflineDataCorruptException();
}

/// Stores app-private generations. Native map resources are managed separately;
/// this source returns their references and never deletes shared SDK files.
class OfflineTripLocalDataSource {
  OfflineTripLocalDataSource(this.root);

  final Directory root;
  Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _pending;
    final completed = Completer<void>();
    _pending = completed.future;
    await previous;
    try {
      return await operation();
    } finally {
      completed.complete();
    }
  }

  Future<List<OfflineTripManifest>> list(int ownerId) => _serialized(() async {
    final all = await _all(ownerId);
    final current = <String, OfflineTripManifest>{};
    for (final item in all) {
      final family = _family(item);
      final existing = current[family];
      if (existing == null || _newest(item, existing) < 0) {
        current[family] = item;
      }
    }
    final result = current.values.toList()..sort(_newest);
    return List.unmodifiable(result);
  });

  /// Native recovery must retain resources of every complete generation,
  /// including an older generation kept for safe replacement rollback.
  Future<List<OfflineTripManifest>> committedGenerations(int ownerId) =>
      _serialized(() async => List.unmodifiable(await _all(ownerId)));

  Future<OfflineTripManifest?> read(int ownerId, int itineraryId) =>
      _serialized(() async {
        _positive(itineraryId);
        final unreadable = <String>[];
        final matches = _matchingFamily(
          await _all(ownerId, unreadable: unreadable),
          itineraryId,
        );
        matches.sort(_newest);
        if (matches.isEmpty && unreadable.isNotEmpty) {
          throw const OfflineDataCorruptException();
        }
        return matches.isEmpty ? null : matches.first;
      });

  /// Pair with [list] to show explicit damaged-package diagnostics instead of
  /// hiding corrupt generations or blocking other healthy downloaded trips.
  Future<List<String>> unreadableGenerations(int ownerId) =>
      _serialized(() async {
        final unreadable = <String>[];
        await _all(ownerId, unreadable: unreadable);
        return List.unmodifiable(unreadable);
      });

  /// User-initiated deletion of a diagnosed corrupt generation. Does not parse
  /// its damaged payload and never accepts a healthy generation or path.
  Future<void> removeUnreadable(int ownerId, String generation) =>
      _serialized(() async {
        _generation(generation);
        final unreadable = <String>[];
        await _all(ownerId, unreadable: unreadable);
        if (!unreadable.contains(generation)) {
          throw StateError('Generation is not diagnosed as unreadable.');
        }
        final owner = await _owner(ownerId);
        final directory = Directory('${owner.path}/$generation');
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw const OfflineDataCorruptException();
        }
        await directory.delete(recursive: true);
      });

  Future<OfflineTripManifest> commit(
    OfflineTripManifest manifest,
  ) => _serialized(() async {
    _generation(manifest.generation);
    final owner = await _owner(manifest.ownerId, create: true);
    final destination = Directory('${owner.path}/${manifest.generation}');
    final staging = Directory('${owner.path}/staging-${manifest.generation}');
    if (await FileSystemEntity.type(destination.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(staging.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw StateError('Offline generation already exists.');
    }
    var sequence = 0;
    for (final existing in await _all(manifest.ownerId)) {
      if (existing.publicationSequence > sequence) {
        sequence = existing.publicationSequence;
      }
    }
    final published = manifest.copyWith(publicationSequence: sequence + 1);
    final bytes = OfflineTripManifestModel.encode(published);
    final measured = published.copyWith(dataBytes: bytes.length + 64);
    if (measured.totalBytes > OfflineTripManifest.maxBytes) {
      throw const OfflineStorageLimitException();
    }
    // Round-trip validation precedes publication (unknown schema/invalid data
    // must never become committed). dataBytes is calculated, never trusted.
    OfflineTripManifestModel.decode(bytes);
    await staging.create();
    try {
      await File(
        '${staging.path}/payload.json',
      ).writeAsBytes(bytes, flush: true);
      await File(
        '${staging.path}/COMMITTED',
      ).writeAsString(sha256.convert(bytes).toString(), flush: true);
      if (manifest.locked) {
        await File('${staging.path}/LOCKED').writeAsString('', flush: true);
      }
      if (manifest.superseded) {
        await File('${staging.path}/SUPERSEDED').writeAsString('', flush: true);
      }
      // Both directories share a filesystem. Readers ignore staging names;
      // publication is the single directory rename, retaining the old version.
      await staging.rename(destination.path);
      return measured;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  });

  /// Returns all removed generations so the repository may release only their
  /// SDK region references after checking other committed packages.
  Future<List<OfflineTripManifest>> remove(int ownerId, int itineraryId) =>
      _serialized(() async {
        _positive(itineraryId);
        final removed = _matchingFamily(await _all(ownerId), itineraryId);
        final owner = await _owner(ownerId);
        for (final item in removed) {
          await Directory(
            '${owner.path}/${item.generation}',
          ).delete(recursive: true);
        }
        return List.unmodifiable(removed);
      });

  /// Call after the replacement and its native resources are verified. Returns
  /// released references for repository-owned SDK cleanup. A crash between
  /// local deletion and SDK removal may leave an orphan native region; startup
  /// repository reconciliation must remove only unreferenced regions.
  Future<List<OfflineTripManifest>> removeObsolete(
    int ownerId,
    int itineraryId,
  ) => _serialized(() async {
    _positive(itineraryId);
    final matches = _matchingFamily(await _all(ownerId), itineraryId)
      ..sort(_newest);
    final obsolete = matches.skip(1).toList();
    final owner = await _owner(ownerId);
    for (final item in obsolete) {
      await Directory(
        '${owner.path}/${item.generation}',
      ).delete(recursive: true);
    }
    return List.unmodifiable(obsolete);
  });

  Future<void> setLocked(int ownerId, int itineraryId, bool value) =>
      _flag(ownerId, itineraryId, 'LOCKED', value);

  Future<void> setSuperseded(int ownerId, int itineraryId, bool value) =>
      _flag(ownerId, itineraryId, 'SUPERSEDED', value);

  Future<void> _flag(int ownerId, int itineraryId, String name, bool value) =>
      _serialized(() async {
        _positive(itineraryId);
        final matches = _matchingFamily(await _all(ownerId), itineraryId);
        final owner = await _owner(ownerId);
        for (final item in matches) {
          final flag = File('${owner.path}/${item.generation}/$name');
          if (value) {
            await flag.writeAsString('', flush: true);
          } else if (await flag.exists()) {
            await flag.delete();
          }
        }
      });

  /// Call only before starting native downloads. The app repository serializes
  /// startup recovery with download operations so live staging is not removed.
  Future<void> recover(int ownerId) => _serialized(() async {
    final owner = await _owner(ownerId);
    if (!await owner.exists()) return;
    await for (final entity in owner.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = _basename(entity.path);
      if (name.startsWith('staging-') ||
          !await File('${entity.path}/COMMITTED').exists()) {
        await entity.delete(recursive: true);
      }
    }
  });

  Future<List<OfflineTripManifest>> _all(
    int ownerId, {
    List<String>? unreadable,
  }) async {
    final owner = await _owner(ownerId);
    if (!await owner.exists()) return [];
    final result = <OfflineTripManifest>[];
    await for (final entity in owner.list(followLinks: false)) {
      if (entity is! Directory ||
          _basename(entity.path).startsWith('staging-')) {
        continue;
      }
      final marker = File('${entity.path}/COMMITTED');
      if (!await marker.exists()) continue;
      try {
        final payload = File('${entity.path}/payload.json');
        if (await FileSystemEntity.type(payload.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await FileSystemEntity.type(marker.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await payload.length() > OfflineTripManifest.maxBytes) {
          throw const OfflineDataCorruptException();
        }
        final bytes = await payload.readAsBytes();
        if (await marker.readAsString() != sha256.convert(bytes).toString()) {
          throw const OfflineDataCorruptException();
        }
        final manifest = OfflineTripManifestModel.decode(bytes);
        if (manifest.ownerId != ownerId ||
            manifest.generation != _basename(entity.path) ||
            manifest.totalBytes > OfflineTripManifest.maxBytes) {
          throw const OfflineDataCorruptException();
        }
        _generation(manifest.generation);
        result.add(
          manifest.copyWith(
            locked: await File('${entity.path}/LOCKED').exists(),
            superseded: await File('${entity.path}/SUPERSEDED').exists(),
          ),
        );
      } on OfflineDataCorruptException {
        unreadable?.add(_basename(entity.path));
      } on FormatException {
        unreadable?.add(_basename(entity.path));
      } on TypeError {
        unreadable?.add(_basename(entity.path));
      } on ArgumentError {
        unreadable?.add(_basename(entity.path));
      } on FileSystemException {
        unreadable?.add(_basename(entity.path));
      }
    }
    return result;
  }

  Future<Directory> _owner(int ownerId, {bool create = false}) async {
    _positive(ownerId);
    final owner = Directory('${root.path}/$ownerId');
    final type = await FileSystemEntity.type(owner.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const OfflineDataCorruptException();
    }
    if (create) await owner.create(recursive: true);
    return owner;
  }

  static List<OfflineTripManifest> _matchingFamily(
    List<OfflineTripManifest> all,
    int id,
  ) {
    final families = all
        .where(
          (item) =>
              item.itineraryId == id ||
              item.snapshot.requestedItineraryId == id,
        )
        .map(_family)
        .toSet();
    return all.where((item) => families.contains(_family(item))).toList();
  }

  static String _family(OfflineTripManifest item) {
    final requestId = item.snapshot.itinerary.schedulingRequestId;
    return requestId > 0
        ? 'schedule:$requestId'
        : 'itinerary:${item.itineraryId}';
  }

  static void _positive(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'Must be positive.');
  }

  static void _generation(String generation) {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$').hasMatch(generation) ||
        generation.startsWith('staging-')) {
      throw ArgumentError.value(
        generation,
        'generation',
        'Invalid generation.',
      );
    }
  }

  static String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

  static int _newest(OfflineTripManifest a, OfflineTripManifest b) {
    final sequence = b.publicationSequence.compareTo(a.publicationSequence);
    if (sequence != 0) return sequence;
    // Legacy generations without an assigned sequence keep their old ordering.
    final timestamp = b.downloadedAtUtc.compareTo(a.downloadedAtUtc);
    if (timestamp != 0) return timestamp;
    final version = b.version.compareTo(a.version);
    return version != 0 ? version : b.generation.compareTo(a.generation);
  }
}
