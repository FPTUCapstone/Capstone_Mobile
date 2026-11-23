import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';

final class LiveOfflinePackageState {
  const LiveOfflinePackageState({
    this.manifest,
    this.isLoading = false,
    this.isDownloading = false,
    this.isCancelling = false,
    this.progress,
    this.error,
    this.completionSequence = 0,
  });
  final OfflineTripManifest? manifest;
  final bool isLoading;
  final bool isDownloading;
  final bool isCancelling;
  final OfflineDownloadProgress? progress;
  final String? error;
  final int completionSequence;
  LiveOfflinePackageState copyWith({
    OfflineTripManifest? manifest,
    bool clearManifest = false,
    bool? isLoading,
    bool? isDownloading,
    bool? isCancelling,
    OfflineDownloadProgress? progress,
    bool clearProgress = false,
    String? error,
    int? completionSequence,
  }) => LiveOfflinePackageState(
    manifest: clearManifest ? null : manifest ?? this.manifest,
    isLoading: isLoading ?? this.isLoading,
    isDownloading: isDownloading ?? this.isDownloading,
    isCancelling: isCancelling ?? this.isCancelling,
    progress: clearProgress ? null : progress ?? this.progress,
    error: error,
    completionSequence: completionSequence ?? this.completionSequence,
  );
}

final class LiveOfflinePackageCubit extends Cubit<LiveOfflinePackageState> {
  LiveOfflinePackageCubit(
    this.repository, {
    required this.itineraryId,
    this.networkInfo,
  }) : super(const LiveOfflinePackageState());
  final OfflineTripRepository repository;
  final int itineraryId;
  final NetworkInfo? networkInfo;
  int _epoch = 0;
  StreamSubscription<bool>? _connectivity;
  Timer? _reconnect;
  bool _watching = false;
  bool _online = false;

  Future<void> load() async {
    if (state.isDownloading) return;
    final epoch = ++_epoch;
    emit(state.copyWith(isLoading: true));
    try {
      final manifest = await repository.read(itineraryId);
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          manifest: manifest,
          clearManifest: manifest == null,
          isLoading: false,
        ),
      );
      await _watchAfterLocalRead();
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(
          state.copyWith(
            isLoading: false,
            clearManifest: error is AuthenticationFailure,
            error: OfflineUiText.safeError(error, OfflineUiText.loadError),
          ),
        );
      }
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
        _reconnect = Timer(const Duration(milliseconds: 300), () {
          if (!isClosed && state.manifest != null) unawaited(checkForUpdate());
        });
      },
      onError: (Object _) {
        _online = false;
      },
    );
    if (_online && state.manifest != null) unawaited(checkForUpdate());
  }

  Future<void> checkForUpdate() async {
    if (state.isDownloading || state.isLoading) return;
    final epoch = ++_epoch;
    try {
      final manifest = await repository.checkForUpdate(itineraryId);
      if (!isClosed && epoch == _epoch) {
        emit(state.copyWith(manifest: manifest));
      }
    } catch (error) {
      if (isClosed || epoch != _epoch) return;
      OfflineTripManifest? current;
      try {
        current = await repository.read(itineraryId);
      } catch (_) {
        current = error is AuthenticationFailure
            ? null
            : state.manifest?.copyWith(mapResourcesAvailable: false);
      }
      if (!isClosed && epoch == _epoch) {
        emit(
          state.copyWith(
            manifest: current,
            clearManifest: current == null,
            error: OfflineUiText.safeError(error),
          ),
        );
      }
    }
  }

  Future<void> download() async {
    if (state.isDownloading ||
        state.isLoading ||
        state.manifest?.locked == true) {
      return;
    }
    final epoch = ++_epoch;
    emit(state.copyWith(isDownloading: true));
    try {
      final result = await repository.download(
        itineraryId,
        onProgress: (progress) {
          if (!isClosed && epoch == _epoch) {
            emit(state.copyWith(progress: progress));
          }
        },
      );
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          manifest: result,
          isDownloading: false,
          isCancelling: false,
          clearProgress: true,
          completionSequence: state.completionSequence + 1,
        ),
      );
    } catch (error) {
      if (isClosed || epoch != _epoch) return;
      if (error is OfflineOperationCancelled && state.isCancelling) return;
      OfflineTripManifest? current;
      try {
        current = await repository.read(itineraryId);
      } catch (_) {
        current = error is AuthenticationFailure
            ? null
            : state.manifest?.copyWith(mapResourcesAvailable: false);
      }
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          manifest: current,
          clearManifest: current == null,
          isDownloading: false,
          clearProgress: true,
          error: error is OfflineOperationCancelled
              ? null
              : OfflineUiText.safeError(error),
        ),
      );
    }
  }

  Future<void> cancel() async {
    if (!state.isDownloading || state.isCancelling) return;
    final epoch = _epoch;
    final completionSequence = state.completionSequence;
    emit(state.copyWith(isCancelling: true));
    try {
      await repository.cancel();
      if (isClosed ||
          epoch != _epoch ||
          state.completionSequence != completionSequence) {
        return;
      }
      ++_epoch;
      emit(
        state.copyWith(
          isDownloading: false,
          isCancelling: false,
          clearProgress: true,
        ),
      );
    } catch (error) {
      if (!isClosed &&
          epoch == _epoch &&
          state.completionSequence == completionSequence) {
        emit(
          state.copyWith(
            isCancelling: false,
            clearManifest: error is AuthenticationFailure,
            error: OfflineUiText.safeError(error),
          ),
        );
      }
    }
  }

  Future<void> remove() async {
    if (state.isDownloading || state.isLoading) return;
    final epoch = ++_epoch;
    emit(state.copyWith(isLoading: true));
    try {
      await repository.remove(itineraryId);
      if (!isClosed && epoch == _epoch) {
        emit(state.copyWith(clearManifest: true, isLoading: false));
      }
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(
          state.copyWith(
            isLoading: false,
            clearManifest: error is AuthenticationFailure,
            error: OfflineUiText.safeError(error),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    ++_epoch;
    _reconnect?.cancel();
    await _connectivity?.cancel();
    if (state.isDownloading) {
      try {
        await repository.cancel();
      } catch (_) {
        // The repository retains cleanup failure state. A disposed screen
        // cannot announce successful cancellation or render a late result.
      }
    }
    return super.close();
  }
}
