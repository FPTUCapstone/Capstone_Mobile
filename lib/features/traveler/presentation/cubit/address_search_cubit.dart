import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/address_search_repository.dart';

enum AddressSearchStatus { idle, searching, ready, failure }

final class AddressSearchState extends Equatable {
  const AddressSearchState({
    this.status = AddressSearchStatus.idle,
    this.candidates = const [],
    this.resolvingId,
    this.message,
  });

  final AddressSearchStatus status;
  final List<AddressCandidate> candidates;

  /// The candidate whose location is being fetched after the Traveler picked it.
  final String? resolvingId;
  final String? message;

  @override
  List<Object?> get props => [status, candidates, resolvingId, message];
}

final class AddressSearchCubit extends Cubit<AddressSearchState> {
  AddressSearchCubit({required AddressSearchRepository repository})
    : _repository = repository,
      super(const AddressSearchState());

  static const _unavailableMessage = 'Address search is unavailable right now.';

  final AddressSearchRepository _repository;
  int _generation = 0;

  bool get isAvailable => _repository.isAvailable;

  Future<void> search(String query, {DeviceLocation? near}) async {
    final generation = ++_generation;
    if (!_repository.isAvailable || query.trim().isEmpty) {
      emit(const AddressSearchState());
      return;
    }
    emit(const AddressSearchState(status: AddressSearchStatus.searching));
    try {
      final candidates = await _repository.suggest(query, near: near);
      if (generation != _generation || isClosed) return;
      emit(
        AddressSearchState(
          status: AddressSearchStatus.ready,
          candidates: candidates,
        ),
      );
    } catch (error) {
      if (generation != _generation || isClosed) return;
      emit(
        AddressSearchState(
          status: AddressSearchStatus.failure,
          message: _message(error),
        ),
      );
    }
  }

  /// Fetches the picked [candidate]'s location; `null` when it is unavailable,
  /// with the reason in the state and the suggestions kept for another pick.
  Future<AddressSuggestion?> resolve(AddressCandidate candidate) async {
    if (state.resolvingId != null) return null;
    final generation = ++_generation;
    final candidates = state.candidates;
    emit(
      AddressSearchState(
        status: AddressSearchStatus.ready,
        candidates: candidates,
        resolvingId: candidate.id,
      ),
    );
    try {
      final address = await _repository.resolve(candidate);
      if (generation != _generation || isClosed) return null;
      emit(
        AddressSearchState(
          status: AddressSearchStatus.ready,
          candidates: candidates,
        ),
      );
      return address;
    } catch (error) {
      if (generation != _generation || isClosed) return null;
      emit(
        AddressSearchState(
          status: AddressSearchStatus.ready,
          candidates: candidates,
          message: _message(error),
        ),
      );
      return null;
    }
  }

  void reset() {
    _generation++;
    emit(const AddressSearchState());
  }

  static String _message(Object error) =>
      error is Failure ? error.message : _unavailableMessage;
}
