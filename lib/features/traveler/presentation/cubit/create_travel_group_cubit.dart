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

  static const _maxNameLength = 150;

  /// Validates [name] then calls the repository with [itineraryId].
  ///
  /// Emits [validationFailure] → [initial] for client-side errors.
  /// Emits [submitting] → [success] or [failure] for API calls.
  Future<void> submit({required String name, required int itineraryId}) async {
    final trimmed = name.trim();

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
    try {
      final group = await _repository.createTravelGroup(
        name: trimmed,
        itineraryId: itineraryId,
      );
      emit(CreateTravelGroupState.success(group));
    } on Failure catch (e) {
      emit(CreateTravelGroupState.failure(e.message));
    } catch (_) {
      emit(
        const CreateTravelGroupState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      );
    }
  }
}
