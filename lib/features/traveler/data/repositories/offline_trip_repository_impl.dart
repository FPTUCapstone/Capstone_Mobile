import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_map_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_local_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/offline_trip_manifest_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:uuid/uuid.dart';

final class _Transfer {
  bool cancelled = false;
  bool publishing = false;
  int owner = 0;
  String? session;
}

/// Coordinates an account-scoped, durable package. The committed directory is
/// never replaced until all required SDK resources and server snapshot verify.
final class OfflineTripRepositoryImpl implements OfflineTripRepository {
  OfflineTripRepositoryImpl({
    required Future<OfflineTripLocalDataSource> Function() local,
    required OfflineMapDataSource maps,
    required OfflineTripRemoteDataSource remote,
    required Future<int?> Function() ownerId,
    required Future<int?> Function() onlineOwnerId,
    required Future<String?> Function() sessionKey,
    required bool Function() isMapConfigured,
  }) : _createLocal = local,
       _maps = maps,
       _remote = remote,
       _ownerId = ownerId,
       _onlineOwnerId = onlineOwnerId,
       _sessionKey = sessionKey,
       _isMapConfigured = isMapConfigured;

  final Future<OfflineTripLocalDataSource> Function() _createLocal;
  final OfflineMapDataSource _maps;
  final OfflineTripRemoteDataSource _remote;
  final Future<int?> Function() _ownerId, _onlineOwnerId;
  final Future<String?> Function() _sessionKey;
  final bool Function() _isMapConfigured;
  Future<OfflineTripLocalDataSource>? _localFuture;
  Future<void>? _recovery;
  _Transfer? _active;
  bool _mutating = false;

  Future<OfflineTripLocalDataSource> _local() =>
      _localFuture ??= _createLocal().catchError((Object error) {
        _localFuture = null;
        throw error;
      });

  Future<(int, String)> _account({bool online = false}) async {
    final key = await _sessionKey();
    final owner = await (online ? _onlineOwnerId() : _ownerId());
    if (owner == null ||
        owner <= 0 ||
        key == null ||
        key != await _sessionKey()) {
      throw const AuthenticationFailure();
    }
    return (owner, key);
  }

  Future<void> _sameAccount(int owner, String session) async {
    if (await _ownerId() != owner || await _sessionKey() != session) {
      throw const AuthenticationFailure(
        'Tài khoản đã thay đổi. Vui lòng mở lại mục dữ liệu ngoại tuyến.',
      );
    }
  }

  Future<void> _check(_Transfer transfer) async {
    if (transfer.cancelled) throw const OfflineOperationCancelled();
    await _sameAccount(transfer.owner, transfer.session!);
    if (transfer.cancelled) throw const OfflineOperationCancelled();
  }

  /// Reconcile SDK references left by a process crash. Only our own region
  /// prefix is removable; smoke tests and regions belonging to other features
  /// are untouched. Retained packages of all accounts keep their references.
  Future<void> _recover() =>
      _recovery ??= _recoverOnce().catchError((Object error) {
        _recovery = null;
        throw error;
      });

  Future<void> _recoverOnce() async {
    final source = await _local();
    final references = <String>{};
    if (await source.root.exists()) {
      await for (final entry in source.root.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final name = entry.path.split(RegExp(r'[/\\]')).last;
        final owner = int.tryParse(name);
        if (owner == null || owner <= 0) continue;
        await source.recover(owner);
        for (final package in await source.committedGenerations(owner)) {
          references.add(package.regionId);
        }
      }
    }
    for (final region in await _maps.regions()) {
      if (region.startsWith('tripmate-offline-') &&
          !references.contains(region)) {
        await _maps.remove(region);
      }
    }
  }

  @override
  Future<List<OfflineTripManifest>> list() async {
    final (owner, key) = await _account();
    await _recover();
    final packages = await (await _local()).list(owner);
    final result = <OfflineTripManifest>[];
    for (final package in packages) {
      var available = false;
      if (!package.locked) {
        try {
          await _verify(package);
          available = true;
        } on ServerFailure {
          available = false;
        }
      }
      result.add(package.copyWith(mapResourcesAvailable: available));
    }
    await _sameAccount(owner, key);
    return List.unmodifiable(result);
  }

  @override
  Future<OfflineTripManifest?> read(int itineraryId) async {
    final (owner, key) = await _account();
    await _recover();
    final package = await (await _local()).read(owner, itineraryId);
    if (package != null && !package.locked) await _verify(package);
    await _sameAccount(owner, key);
    return package?.copyWith(mapResourcesAvailable: !package.locked);
  }

  Future<void> _verify(OfflineTripManifest package) async {
    try {
      final map = await _maps.verify(package.regionId);
      if (map.regionId != package.regionId ||
          map.styleUri != package.styleUri ||
          map.totalBytes + package.dataBytes > OfflineTripManifest.maxBytes) {
        throw const FormatException(
          'Offline resources do not match the manifest.',
        );
      }
    } catch (_) {
      throw const ServerFailure(
        'Bản đồ đã lưu bị thiếu hoặc hư hỏng. Vui lòng tải lại lịch trình này.',
      );
    }
  }

  Future<int> _freeBytes() async {
    final value = (await _maps.storage())['freeBytes'];
    if (value is! int || value < 0) {
      throw const ServerFailure(
        'Không thể kiểm tra dung lượng bộ nhớ thiết bị.',
      );
    }
    return value;
  }

  @override
  Future<OfflineTripManifest> download(
    int itineraryId, {
    void Function(OfflineDownloadProgress)? onProgress,
  }) async {
    if (_mutating) {
      throw const ConflictFailure('Một thao tác ngoại tuyến khác đang chạy.');
    }
    final transfer = _Transfer();
    _mutating = true;
    _active = transfer;
    String? acquiredRegion;
    var committed = false;
    try {
      final (owner, key) = await _account(online: true);
      transfer.owner = owner;
      transfer.session = key;
      await _check(transfer);
      if (!_isMapConfigured()) {
        throw const ServerFailure(
          'Bản đồ ngoại tuyến chưa được cấu hình trên bản dựng này.',
        );
      }
      await _recover();
      await _check(transfer);
      if (await _freeBytes() < OfflineTripManifest.maxBytes) {
        throw const ValidationFailure(
          'Không đủ dung lượng bộ nhớ. Cần ít nhất 150 MB trống để lưu dữ liệu bản đồ ngoại tuyến.',
        );
      }
      onProgress?.call(
        const OfflineDownloadProgress(
          phase: OfflineTransferPhase.preparing,
          fraction: 0,
        ),
      );
      final snapshot = await _remote.capture(
        ownerId: owner,
        itineraryId: itineraryId,
        isCancelled: () => transfer.cancelled,
      );
      await _check(transfer);
      final points = <NavigationCoordinate>[
        for (final route in snapshot.routes) ...route.geometry,
        for (final poi in snapshot.pois)
          NavigationCoordinate(
            latitude: poi.latitude,
            longitude: poi.longitude,
          ),
        for (final item in snapshot.itinerary.visitItems)
          if (item.latitude != null && item.longitude != null)
            NavigationCoordinate(
              latitude: item.latitude!,
              longitude: item.longitude!,
            ),
        if (snapshot.itinerary.startLocation case final location?)
          NavigationCoordinate(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        if (snapshot.itinerary.endLocation case final location?)
          NavigationCoordinate(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
      ];
      final geometry = offlineCoverageGeometry(points);
      final generation = const Uuid().v4();
      final region = 'tripmate-offline-$owner-$generation';
      final downloadedAt = DateTime.now().toUtc();
      OfflineTripManifest manifest(OfflineMapDownload resources) =>
          OfflineTripManifest(
            snapshot: snapshot,
            generation: generation,
            regionId: region,
            styleUri: resources.styleUri,
            styleBytes: resources.styleBytes,
            tileBytes: resources.tileBytes,
            downloadedAtUtc: downloadedAt,
          );
      final placeholder = manifest(
        OfflineMapDownload(
          regionId: region,
          styleUri: 'mapbox://styles/mapbox/standard',
          styleBytes: OfflineTripManifest.maxBytes,
          tileBytes: OfflineTripManifest.maxBytes,
        ),
      ).copyWith(publicationSequence: 9223372036854775807);
      // Conservative JSON overhead includes maximal resource byte digits.
      final overhead = OfflineTripManifestModel.encodedSize(placeholder);
      final budget = OfflineTripManifest.maxBytes - overhead;
      if (budget <= 0) {
        throw const ValidationFailure(
          'Lịch trình này vượt quá giới hạn gói ngoại tuyến 150 MB.',
        );
      }
      onProgress?.call(
        const OfflineDownloadProgress(
          phase: OfflineTransferPhase.itinerary,
          fraction: .2,
        ),
      );
      final estimate = await _maps.estimate(
        regionId: region,
        geometry: geometry,
      );
      await _check(transfer);
      if (estimate != null && estimate > budget) {
        throw const ValidationFailure(
          'Lịch trình này vượt quá giới hạn gói ngoại tuyến 150 MB.',
        );
      }
      if (await _freeBytes() < OfflineTripManifest.maxBytes) {
        throw const ValidationFailure(
          'Không đủ dung lượng tạm để giữ gói cũ trong khi tải mới. Cần ít nhất 150 MB trống.',
        );
      }
      await _check(transfer);
      final resources = await _maps.download(
        regionId: region,
        geometry: geometry,
        maxBytes: budget,
        onProgress: (bytes, completed, required) {
          if (transfer.cancelled) return;
          final fraction = required > 0
              ? (completed / required).clamp(0.0, 1.0)
              : 0.0;
          onProgress?.call(
            OfflineDownloadProgress(
              phase: OfflineTransferPhase.maps,
              fraction: .2 + .7 * fraction,
              completedBytes: bytes,
              estimatedBytes: estimate == null ? null : estimate + overhead,
            ),
          );
        },
      );
      acquiredRegion = region;
      await _check(transfer);
      if (resources.regionId != region || resources.totalBytes > budget) {
        throw const ValidationFailure(
          'Gói đã tải vượt quá giới hạn 150 MB hoặc chưa đầy đủ.',
        );
      }
      var saved = manifest(resources);
      await _verify(saved);
      await _check(transfer);
      onProgress?.call(
        OfflineDownloadProgress(
          phase: OfflineTransferPhase.verifying,
          fraction: .95,
          completedBytes: resources.totalBytes,
        ),
      );
      try {
        await _remote.validate(snapshot);
      } on PermissionFailure {
        await _sameAccount(owner, key);
        await (await _local()).setLocked(owner, itineraryId, true);
        rethrow;
      }
      await _check(transfer);
      if (await _freeBytes() < OfflineTripManifestModel.encodedSize(saved)) {
        throw const ValidationFailure(
          'Bộ nhớ thiết bị đã đầy. Gói dữ liệu trước đó vẫn được giữ lại.',
        );
      }
      await _check(transfer);
      // Atomic publication is the explicit commit point: the UI disables
      // Cancel during verification, and a late intent is rejected rather than
      // falsely claiming that an already durable complete package was canceled.
      transfer.publishing = true;
      onProgress?.call(
        OfflineDownloadProgress(
          phase: OfflineTransferPhase.publishing,
          fraction: .98,
          completedBytes: resources.totalBytes,
        ),
      );
      saved = await (await _local()).commit(saved);
      committed = true;
      // A session change during the durable write cannot make its result visible
      // to a new account. The saved files remain confined to the original owner.
      await _check(transfer);
      final obsolete = await (await _local()).removeObsolete(
        owner,
        saved.itineraryId,
      );
      for (final old in obsolete) {
        if (old.regionId != region) {
          try {
            await _maps.remove(old.regionId);
          } catch (_) {
            _recovery = null;
            throw const ServerFailure(
              'Đã lưu gói mới nhưng chưa dọn xong bản đồ cũ. Vui lòng mở lại dữ liệu ngoại tuyến để thử dọn lại.',
            );
          }
        }
      }
      onProgress?.call(
        OfflineDownloadProgress(
          phase: OfflineTransferPhase.verifying,
          fraction: 1,
          completedBytes: saved.totalBytes,
        ),
      );
      return saved.copyWith(mapResourcesAvailable: true);
    } catch (error) {
      if (error is PlatformException &&
          (error.code == 'cleanup_failed' || error.code == 'cleanup_pending')) {
        _recovery = null;
      }
      if (!committed && acquiredRegion != null) {
        try {
          await _maps.remove(acquiredRegion);
        } catch (_) {
          _recovery = null;
          throw const ServerFailure(
            'Quá trình dọn dẹp dữ liệu ngoại tuyến chưa hoàn tất. Vui lòng mở lại dữ liệu ngoại tuyến để thử lại.',
          );
        }
      }
      if (error is NetworkFailure) {
        throw const NetworkFailure(
          'Mất kết nối mạng. Quá trình tải bị gián đoạn và không lưu dữ liệu dở dang. Vui lòng thử lại.',
        );
      }
      if (error is OfflineItineraryAccessDenied) {
        await _sameAccount(transfer.owner, transfer.session!);
        await (await _local()).setLocked(transfer.owner, itineraryId, true);
        throw const PermissionFailure(
          'Bạn không còn quyền truy cập lịch trình này.',
        );
      }
      if (error is OfflineOperationCancelled || error is Failure) rethrow;
      if (error is OfflineCaptureCancelled ||
          (error is PlatformException && error.code == 'cancelled')) {
        throw const OfflineOperationCancelled();
      }
      if (error is OfflineStorageLimitException ||
          (error is PlatformException && error.code == 'size_limit')) {
        throw const ValidationFailure(
          'Lịch trình này vượt quá giới hạn gói ngoại tuyến 150 MB.',
        );
      }
      if (error is OfflineDataCorruptException) {
        throw const ServerFailure(
          'Dữ liệu ngoại tuyến đã lưu bị hỏng. Vui lòng xóa dữ liệu không đọc được và tải lại.',
        );
      }
      throw const ServerFailure(
        'Không thể lưu gói ngoại tuyến. Vui lòng thử lại; gói đầy đủ trước đó vẫn được giữ lại.',
      );
    } finally {
      _active = null;
      _mutating = false;
    }
  }

  @override
  Future<void> cancel() async {
    final transfer = _active;
    if (transfer == null) return;
    if (transfer.publishing) {
      throw const ConflictFailure(
        'Đang lưu gói dữ liệu. Vui lòng chờ hoàn tất.',
      );
    }
    transfer.cancelled = true;
    _remote.cancel();
    try {
      await _maps.cancel();
    } catch (_) {
      _recovery = null;
      throw const ServerFailure(
        'Quá trình dọn dẹp sau khi hủy chưa hoàn tất. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<void> remove(int itineraryId) async {
    if (_mutating) {
      throw const ConflictFailure(
        'Vui lòng chờ thao tác ngoại tuyến hiện tại hoàn tất.',
      );
    }
    _mutating = true;
    try {
      final (owner, key) = await _account();
      await _recover();
      await _sameAccount(owner, key);
      final removed = await (await _local()).remove(owner, itineraryId);
      for (final old in removed) {
        await _maps.remove(old.regionId);
      }
      await _sameAccount(owner, key);
    } catch (error) {
      _recovery = null;
      if (error is Failure) rethrow;
      throw const ServerFailure(
        'Quá trình xóa dữ liệu ngoại tuyến chưa hoàn tất. Vui lòng mở lại dữ liệu ngoại tuyến để thử dọn lại.',
      );
    } finally {
      _mutating = false;
    }
  }

  @override
  Future<OfflineTripManifest?> checkForUpdate(int itineraryId) async {
    if (_mutating) {
      throw const ConflictFailure(
        'Vui lòng chờ thao tác ngoại tuyến hiện tại hoàn tất.',
      );
    }
    _mutating = true;
    try {
      final (owner, key) = await _account(online: true);
      final source = await _local();
      final saved = await source.read(owner, itineraryId);
      if (saved == null) return null;
      try {
        final current = await _remote.current(
          saved.snapshot.requestedItineraryId,
        );
        await _sameAccount(owner, key);
        final changed =
            OfflineTripManifestModel.itineraryFingerprint(current) !=
            OfflineTripManifestModel.itineraryFingerprint(
              saved.snapshot.itinerary,
            );
        await source.setSuperseded(owner, itineraryId, changed);
        return await read(itineraryId);
      } on PermissionFailure {
        await _sameAccount(owner, key);
        await source.setLocked(owner, itineraryId, true);
        rethrow;
      }
    } finally {
      _mutating = false;
    }
  }

  @override
  Future<List<String>> unreadableGenerations() async {
    final (owner, key) = await _account();
    final result = await (await _local()).unreadableGenerations(owner);
    await _sameAccount(owner, key);
    return result;
  }

  @override
  Future<void> removeUnreadable(String generation) async {
    if (_mutating) {
      throw const ConflictFailure(
        'Vui lòng chờ thao tác ngoại tuyến hiện tại hoàn tất.',
      );
    }
    _mutating = true;
    try {
      final (owner, key) = await _account();
      await (await _local()).removeUnreadable(owner, generation);
      await _sameAccount(owner, key);
      _recovery = null;
      await _recover();
    } finally {
      _mutating = false;
    }
  }
}

/// Minimal longitude interval, expanded by one kilometre, split at the date
/// line. A cross-date-line trip must not turn into a nearly global download.
Map<String, Object?> offlineCoverageGeometry(
  List<NavigationCoordinate> points,
) {
  if (points.isEmpty ||
      points.any(
        (p) =>
            !p.latitude.isFinite ||
            !p.longitude.isFinite ||
            p.latitude.abs() > 85 ||
            p.longitude.abs() > 180,
      )) {
    throw const ValidationFailure(
      'Lịch trình này không có khu vực bản đồ được hỗ trợ để tải.',
    );
  }
  final south =
      points.map((p) => p.latitude).reduce(math.min) -
      OfflineTripManifest.coverageBufferMeters / 111320;
  final north =
      points.map((p) => p.latitude).reduce(math.max) +
      OfflineTripManifest.coverageBufferMeters / 111320;
  if (south < -85.051128 || north > 85.051128) {
    throw const ValidationFailure(
      'Lịch trình nằm ngoài khu vực bản đồ ngoại tuyến được hỗ trợ.',
    );
  }
  final padding =
      OfflineTripManifest.coverageBufferMeters /
      (111320 * math.cos(math.max(south.abs(), north.abs()) * math.pi / 180));
  final longitudes = points.map((p) => (p.longitude + 360) % 360).toList()
    ..sort();
  var gap = -1.0, index = 0;
  for (var i = 0; i < longitudes.length; i++) {
    final next = i + 1 < longitudes.length
        ? longitudes[i + 1]
        : longitudes.first + 360;
    if (next - longitudes[i] > gap) {
      gap = next - longitudes[i];
      index = i;
    }
  }
  var west = longitudes[(index + 1) % longitudes.length];
  var east = longitudes[index];
  if (east < west) east += 360;
  west -= padding;
  east += padding;
  while (west > 180) {
    west -= 360;
    east -= 360;
  }
  while (west < -180) {
    west += 360;
    east += 360;
  }
  List<List<List<double>>> polygon(double left, double right) => [
    [
      [left, south],
      [right, south],
      [right, north],
      [left, north],
      [left, south],
    ],
  ];
  if (east > 180) {
    return {
      'type': 'MultiPolygon',
      'coordinates': [polygon(west, 180), polygon(-180, east - 360)],
    };
  }
  return {'type': 'Polygon', 'coordinates': polygon(west, east)};
}
