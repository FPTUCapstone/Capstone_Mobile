import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_state.dart';

final class _PendingOperation {
  const _PendingOperation({
    required this.name,
    required this.itineraryId,
    required this.idempotencyKey,
  });

  final String name;
  final int itineraryId;
  final String idempotencyKey;

  bool matches({required String name, required int itineraryId}) =>
      this.name == name && this.itineraryId == itineraryId;
}

/// Cubit that handles the Create Travel Group use case.
///
/// Input: [TravelGroupRepository] injected via constructor.
/// Output: [CreateTravelGroupState] transitions consumed by [CreateTravelGroupPage].
final class CreateTravelGroupCubit extends Cubit<CreateTravelGroupState> {
  CreateTravelGroupCubit({
    required TravelGroupRepository repository,
    String Function()? operationKeyFactory,
  }) : _repository = repository,
       _operationKeyFactory = operationKeyFactory ?? _generateIdempotencyKey,
       super(const CreateTravelGroupState.initial());

  final TravelGroupRepository _repository;
  final String Function() _operationKeyFactory;
  _PendingOperation? _pendingOperation;

  static const _maxNameLength = 150;

  /// Validates [name] then calls the repository.
  ///
  /// Emits [validationFailure] → [initial] for client-side errors.
  /// Emits [submitting] → [success] or [failure] for API calls.
  Future<void> submit({required String name, required int itineraryId}) async {
    if (isClosed || state.status == CreateTravelGroupStatus.submitting) {
      return;
    }

    final trimmed = name.trim();

    if (itineraryId <= 0) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'Vui lòng chọn một lịch trình.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    if (trimmed.isEmpty) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'Trường này là bắt buộc.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    if (trimmed.length > _maxNameLength) {
      emit(
        const CreateTravelGroupState.validationFailure(
          'Tên nhóm không được vượt quá 150 ký tự.',
        ),
      );
      emit(const CreateTravelGroupState.initial());
      return;
    }

    final pending = _pendingOperation;
    final idempotencyKey =
        (pending != null &&
            pending.matches(name: trimmed, itineraryId: itineraryId))
        ? pending.idempotencyKey
        : _operationKeyFactory();

    _pendingOperation = _PendingOperation(
      name: trimmed,
      itineraryId: itineraryId,
      idempotencyKey: idempotencyKey,
    );

    emit(const CreateTravelGroupState.submitting());
    try {
      final group = await _repository.createTravelGroup(
        name: trimmed,
        itineraryId: itineraryId,
        idempotencyKey: idempotencyKey,
      );
      if (isClosed) return;
      _pendingOperation = null;
      emit(CreateTravelGroupState.success(group));
    } catch (error) {
      if (isClosed) return;
      final message = switch (error) {
        AuthenticationFailure() =>
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.',
        PermissionFailure() => 'Bạn không có quyền truy cập chức năng này.',
        NotFoundFailure(:final message) => message,
        ValidationFailure(:final message) => message,
        ConflictFailure(:final message) => message,
        _ =>
          'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
      };
      if (error is ConflictFailure && error.isIdempotencyKeyPayloadMismatch) {
        _pendingOperation = null;
      }
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
