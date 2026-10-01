import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';

enum LocationSharingStatus {
  initial,
  loading,
  ready,
  forbidden,
  notFound,
  error,
}

final class LocationSharingState extends Equatable {
  const LocationSharingState({
    this.status = LocationSharingStatus.initial,
    this.enabled = false,
    this.permissionGranted = false,
    this.saving = false,
    this.locations = const [],
    this.message,
    this.updatedAtUtc,
  });

  final LocationSharingStatus status;
  final bool enabled;
  final bool permissionGranted;
  final bool saving;
  final List<GroupLocation> locations;
  final String? message;
  final DateTime? updatedAtUtc;

  LocationSharingState copyWith({
    LocationSharingStatus? status,
    bool? enabled,
    bool? permissionGranted,
    bool? saving,
    List<GroupLocation>? locations,
    String? message,
    DateTime? updatedAtUtc,
  }) => LocationSharingState(
    status: status ?? this.status,
    enabled: enabled ?? this.enabled,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    saving: saving ?? this.saving,
    locations: locations ?? this.locations,
    message: message,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );

  @override
  List<Object?> get props => [
    status,
    enabled,
    permissionGranted,
    saving,
    locations,
    message,
    updatedAtUtc,
  ];
}

final class LocationSharingCubit extends Cubit<LocationSharingState> {
  LocationSharingCubit({
    required GroupLocationRepository repository,
    required GroupLocationPublisher publisher,
  }) : _repository = repository,
       _publisher = publisher,
       super(const LocationSharingState());

  final GroupLocationRepository _repository;
  final GroupLocationPublisher _publisher;
  Timer? _refreshTimer;
  int? _groupId;
  int _version = 0;

  Future<void> load(int groupId) async {
    final version = ++_version;
    _groupId = groupId;
    _refreshTimer?.cancel();
    emit(const LocationSharingState(status: LocationSharingStatus.loading));
    try {
      final setting = await _repository.getSetting(groupId);
      final permission = await _publisher.ensurePermission();
      if (isClosed || version != _version) return;
      if (setting.enabled && permission) {
        await _publisher.start(groupId);
      } else if (setting.enabled) {
        try {
          await _repository.clear(groupId);
        } catch (_) {
          // A failed clear is bounded by the server's freshness window.
        }
      }
      final locations = await _repository.getLocations(groupId);
      if (isClosed || version != _version) return;
      emit(
        LocationSharingState(
          status: LocationSharingStatus.ready,
          enabled: setting.enabled,
          permissionGranted: permission,
          updatedAtUtc: setting.updatedAtUtc,
          locations: locations,
        ),
      );
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(refreshLocations()),
      );
    } on PermissionFailure {
      if (!isClosed && version == _version) {
        emit(
          const LocationSharingState(status: LocationSharingStatus.forbidden),
        );
      }
    } on NotFoundFailure {
      if (!isClosed && version == _version) {
        emit(
          const LocationSharingState(status: LocationSharingStatus.notFound),
        );
      }
    } catch (_) {
      if (!isClosed && version == _version) {
        emit(const LocationSharingState(status: LocationSharingStatus.error));
      }
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final groupId = _groupId;
    if (isClosed ||
        groupId == null ||
        state.status != LocationSharingStatus.ready ||
        state.saving) {
      return;
    }
    if (enabled == state.enabled) return;
    final version = _version;
    emit(state.copyWith(saving: true));
    try {
      if (enabled && !await _publisher.ensurePermission(request: true)) {
        if (!isClosed && version == _version) {
          emit(
            state.copyWith(
              saving: false,
              permissionGranted: false,
              message:
                  'Location permission is needed before sharing with this group.',
            ),
          );
        }
        return;
      }

      final setting = await _repository.updateSetting(groupId, enabled);
      if (isClosed || version != _version) return;
      if (enabled) {
        try {
          await _publisher.start(groupId);
          if (isClosed || version != _version) {
            await _publisher.stop(groupId);
            return;
          }
        } catch (_) {
          try {
            await _repository.clear(groupId);
          } catch (_) {
            // Server freshness limit also hides abandoned positions.
          }
          if (!isClosed && version == _version) {
            emit(
              state.copyWith(
                enabled: true,
                permissionGranted: false,
                updatedAtUtc: setting.updatedAtUtc,
                saving: false,
                locations: const [],
                message:
                    'Opt-in saved, but GPS is unavailable. Sharing is paused.',
              ),
            );
          }
          return;
        }
      } else {
        await _publisher.stop(groupId);
        if (isClosed || version != _version) return;
      }
      if (isClosed || version != _version) return;
      emit(
        state.copyWith(
          enabled: setting.enabled,
          permissionGranted: enabled ? true : state.permissionGranted,
          updatedAtUtc: setting.updatedAtUtc,
          saving: false,
          locations: enabled ? state.locations : const [],
          message: enabled
              ? 'Location sharing is on while the app is open.'
              : 'Location sharing is off.',
        ),
      );
      await refreshLocations();
    } catch (_) {
      if (!isClosed && version == _version) {
        emit(
          state.copyWith(
            saving: false,
            message: 'Could not save location sharing. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> refreshLocations() async {
    final groupId = _groupId;
    if (isClosed ||
        groupId == null ||
        state.status != LocationSharingStatus.ready) {
      return;
    }
    final version = _version;
    try {
      final permission = await _publisher.ensurePermission();
      if (isClosed || version != _version) return;
      if (!permission && state.enabled) {
        await _publisher.pauseForPermission();
        if (isClosed || version != _version) return;
      }
      if (permission && state.enabled && !state.permissionGranted) {
        await _publisher.start(groupId);
        if (isClosed || version != _version) {
          await _publisher.stop(groupId);
          return;
        }
      }
      final locations = await _repository.getLocations(groupId);
      if (!isClosed && version == _version) {
        emit(
          state.copyWith(permissionGranted: permission, locations: locations),
        );
      }
    } on PermissionFailure {
      if (!isClosed && version == _version) {
        _refreshTimer?.cancel();
        emit(
          state.copyWith(
            status: LocationSharingStatus.forbidden,
            locations: const [],
          ),
        );
      }
    } catch (_) {
      if (!isClosed && version == _version) {
        emit(state.copyWith(message: 'Could not refresh group locations.'));
      }
    }
  }

  Future<void> openSettings() async {
    await _publisher.openSettings();
  }

  @override
  Future<void> close() async {
    ++_version;
    _refreshTimer?.cancel();
    await super.close();
  }
}
