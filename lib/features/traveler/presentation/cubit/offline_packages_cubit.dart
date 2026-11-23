import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';

final class OfflinePackagesState {
  const OfflinePackagesState({
    this.packages = const [],
    this.unreadable = const [],
    this.isLoading = false,
    this.error,
  });
  final List<OfflineTripManifest> packages;
  final List<String> unreadable;
  final bool isLoading;
  final String? error;
}

final class OfflinePackagesCubit extends Cubit<OfflinePackagesState> {
  OfflinePackagesCubit(this.repository, {this.networkInfo})
    : super(const OfflinePackagesState());
  final OfflineTripRepository repository;
  final NetworkInfo? networkInfo;
  int _epoch = 0;
  bool _mutating = false;
  bool _watching = false;
  bool _online = false;
  bool _checking = false;
  StreamSubscription<bool>? _connectivity;
  Timer? _reconnect;

  Future<void> load() async {
    final epoch = ++_epoch;
    emit(
      OfflinePackagesState(
        packages: state.packages,
        unreadable: state.unreadable,
        isLoading: true,
      ),
    );
    try {
      final packages = await repository.list();
      final unreadable = await repository.unreadableGenerations();
      if (isClosed || epoch != _epoch) return;
      emit(
        OfflinePackagesState(
          packages: List.unmodifiable(packages),
          unreadable: List.unmodifiable(unreadable),
        ),
      );
      await _watchAfterLocalRead();
    } catch (error) {
      if (isClosed || epoch != _epoch) return;
      emit(
        OfflinePackagesState(
          packages: error is AuthenticationFailure ? const [] : state.packages,
          unreadable: error is AuthenticationFailure
              ? const []
              : state.unreadable,
          error: OfflineUiText.safeError(error, OfflineUiText.loadError),
        ),
      );
    }
  }

  Future<void> _watchAfterLocalRead() async {
    final network = networkInfo;
    if (network == null || _watching || isClosed) return;
    _watching = true;
    try {
      _online = await network.isConnected;
    } catch (_) {
      _online = false;
    }
    if (isClosed) return;
    _connectivity = network.onConnectivityChanged.distinct().listen(
      (online) {
        final reconnecting = online && !_online;
        _online = online;
        if (!reconnecting) return;
        _reconnect?.cancel();
        _reconnect = Timer(
          const Duration(milliseconds: 300),
          () => unawaited(_checkUpdates()),
        );
      },
      onError: (Object _) {
        _online = false;
      },
    );
    if (_online) unawaited(_checkUpdates());
  }

  Future<void> _checkUpdates() async {
    if (isClosed || _checking || _mutating || state.isLoading || !_online) {
      return;
    }
    _checking = true;
    final epoch = _epoch;
    try {
      for (final existing in state.packages.toList()) {
        if (isClosed || epoch != _epoch || !_online) return;
        try {
          final checked = await repository.checkForUpdate(existing.itineraryId);
          if (isClosed || epoch != _epoch) return;
          if (checked != null) {
            emit(
              OfflinePackagesState(
                packages: List.unmodifiable(
                  state.packages.map(
                    (p) => p.itineraryId == existing.itineraryId ? checked : p,
                  ),
                ),
                unreadable: state.unreadable,
                error: state.error,
              ),
            );
          }
        } catch (error) {
          if (isClosed || epoch != _epoch) return;
          var packages = state.packages;
          try {
            packages = await repository.list();
          } catch (_) {
            packages = error is AuthenticationFailure
                ? []
                : packages
                      .map((p) => p.copyWith(mapResourcesAvailable: false))
                      .toList();
          }
          if (isClosed || epoch != _epoch) return;
          emit(
            OfflinePackagesState(
              packages: List.unmodifiable(packages),
              unreadable: error is AuthenticationFailure
                  ? const []
                  : state.unreadable,
              error: OfflineUiText.safeError(error),
            ),
          );
        }
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> remove(int itineraryId) =>
      _mutate(() => repository.remove(itineraryId));
  Future<void> removeUnreadable(String generation) =>
      _mutate(() => repository.removeUnreadable(generation));
  Future<void> _mutate(Future<void> Function() action) async {
    if (_mutating) return;
    _mutating = true;
    try {
      await action();
      if (!isClosed) await load();
    } catch (error) {
      if (!isClosed) {
        emit(
          OfflinePackagesState(
            packages: error is AuthenticationFailure
                ? const []
                : state.packages,
            unreadable: error is AuthenticationFailure
                ? const []
                : state.unreadable,
            error: OfflineUiText.safeError(error),
          ),
        );
      }
    } finally {
      _mutating = false;
    }
  }

  @override
  Future<void> close() async {
    ++_epoch;
    _reconnect?.cancel();
    await _connectivity?.cancel();
    return super.close();
  }
}
