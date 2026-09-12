import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_state.dart';

/// Cubit that handles the Create Travel Group use case.
///
/// Input: [TravelGroupRepository] injected via constructor.
/// Output: [CreateTravelGroupState] transitions consumed by [CreateTravelGroupPage].
final class CreateTravelGroupCubit extends Cubit<CreateTravelGroupState> {
  CreateTravelGroupCubit({required TravelGroupRepository repository})
    : _repository = repository,
      super(const CreateTravelGroupState.initial());

  final TravelGroupRepository _repository;
  String? _pendingIdempotencyKey;

  static const _maxNameLength = 150;

  /// Validates [name] then calls the repository.
  ///
  /// Emits [validationFailure] → [initial] for client-side errors.
  /// Emits [submitting] → [success] or [failure] for API calls.
  Future<void> submit({required String name, required int itineraryId}) async {
    final trimmed = name.trim();

    if (itineraryId <= 0) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'Please select an itinerary.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    if (trimmed.isEmpty) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'This field is required.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    if (trimmed.length > _maxNameLength) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'Group name must not exceed 150 characters.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    emit(const CreateTravelGroupState.submitting());
    final idempotencyKey = _pendingIdempotencyKey ??= _generateIdempotencyKey();
    try {
      final group = await _repository.createTravelGroup(
        name: trimmed,
        itineraryId: itineraryId,
        idempotencyKey: idempotencyKey,
      );
      _pendingIdempotencyKey = null;
      emit(CreateTravelGroupState.success(group));
    } catch (error) {
      final message = switch (error) {
        AuthenticationFailure() =>
          'Your session has expired. Please sign in again to continue.',
        PermissionFailure() =>
          'You do not have permission to access this function.',
        _ =>
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      };
      emit(CreateTravelGroupState.failure(message));
    }
  }

  static String _generateIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
