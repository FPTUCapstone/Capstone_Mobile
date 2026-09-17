import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_state.dart';
import 'package:trip_mate_mobile/features/traveler/utils/qr_invitation_parser.dart';
import 'package:uuid/uuid.dart';

/// Cubit handling the Join Shared Group Trip flow (UC-23).
final class JoinTravelGroupCubit extends Cubit<JoinTravelGroupState> {
  JoinTravelGroupCubit({required TravelGroupRepository repository, Uuid? uuid})
    : _repository = repository,
      _uuid = uuid ?? const Uuid(),
      super(const JoinTravelGroupState.initial());

  final TravelGroupRepository _repository;
  final Uuid _uuid;

  String? _currentIdempotencyKey;
  String? _lastSubmittedCode;

  String? get currentIdempotencyKey => _currentIdempotencyKey;

  /// Submits an invitation code or raw QR data to join a travel group.
  Future<void> submit(String? rawInput) async {
    final trimmed = rawInput?.trim() ?? '';

    if (trimmed.isEmpty) {
      emit(
        const JoinTravelGroupState.validationFailure('This field is required.'),
      );
      return;
    }

    final parsedCode = QrInvitationParser.parse(trimmed);
    if (parsedCode == null) {
      emit(
        const JoinTravelGroupState.failure(
          'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.',
        ),
      );
      return;
    }

    // Reuse idempotency key on identical retry, generate new key on modified code
    if (_currentIdempotencyKey == null || _lastSubmittedCode != parsedCode) {
      _currentIdempotencyKey = _uuid.v4();
      _lastSubmittedCode = parsedCode;
    }

    emit(const JoinTravelGroupState.submitting());

    try {
      final group = await _repository.joinTravelGroup(
        invitationCode: parsedCode,
        idempotencyKey: _currentIdempotencyKey!,
      );
      emit(JoinTravelGroupState.success(group));
    } on Failure catch (failure) {
      final message = switch (failure) {
        AuthenticationFailure() =>
          'Your session has expired. Please sign in again to continue.',
        PermissionFailure() =>
          'You do not have permission to access this function.',
        ValidationFailure(:final message) => message,
        ConflictFailure(:final message) => message,
        _ =>
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      };
      emit(JoinTravelGroupState.failure(message));
    } catch (_) {
      emit(
        const JoinTravelGroupState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      );
    }
  }

  void reset() {
    emit(const JoinTravelGroupState.initial());
  }
}
