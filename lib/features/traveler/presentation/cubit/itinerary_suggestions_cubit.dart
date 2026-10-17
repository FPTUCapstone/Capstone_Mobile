import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';

enum SuggestionsStatus { loading, loaded, failure }

final class ItinerarySuggestionsState extends Equatable {
  const ItinerarySuggestionsState({
    this.status = SuggestionsStatus.loading,
    this.suggestions,
    this.message,
  });

  final SuggestionsStatus status;
  final ItinerarySuggestions? suggestions;
  final String? message;

  @override
  List<Object?> get props => [status, suggestions, message];
}

/// Loads the places offered in the add-restaurant / replace sheet.
final class ItinerarySuggestionsCubit extends Cubit<ItinerarySuggestionsState> {
  ItinerarySuggestionsCubit({required ItinerarySuggestionRepository repository})
    : _repository = repository,
      super(const ItinerarySuggestionsState());

  final ItinerarySuggestionRepository _repository;

  Future<void> load({
    required int itineraryId,
    required SuggestionKind kind,
    required int itemId,
  }) async {
    emit(const ItinerarySuggestionsState());
    try {
      final suggestions = await _repository.getSuggestions(
        itineraryId: itineraryId,
        kind: kind,
        itemId: itemId,
      );
      if (isClosed) return;
      emit(
        ItinerarySuggestionsState(
          status: SuggestionsStatus.loaded,
          suggestions: suggestions,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        const ItinerarySuggestionsState(
          status: SuggestionsStatus.failure,
          message: 'Chưa tải được gợi ý. Vui lòng thử lại.',
        ),
      );
    }
  }
}
