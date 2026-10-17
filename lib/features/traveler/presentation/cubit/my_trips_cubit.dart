import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_list_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';

final class MyTripsCubit extends Cubit<MyTripsState> {
  MyTripsCubit({required ItineraryListRepository repository})
    : _repository = repository,
      super(const MyTripsState());

  static const pageSize = 20;
  static const _unavailableMessage = 'Your trips are unavailable right now.';

  final ItineraryListRepository _repository;
  int _generation = 0;
  int _page = 0;

  /// Loads the first page. Trips already on screen stay visible while a
  /// refresh is in flight, and a refresh after "Show more" reloads both pages
  /// so the list does not shrink under the Traveler's scroll position.
  Future<void> load() async {
    final generation = ++_generation;
    final pages = state.trips.length > pageSize ? 2 : 1;
    emit(
      MyTripsState(
        status: MyTripsStatus.loading,
        trips: state.trips,
        totalCount: state.totalCount,
      ),
    );
    try {
      final page = await _repository.listMine(pageSize: pageSize * pages);
      if (generation != _generation || isClosed) return;
      _page = pages;
      emit(
        MyTripsState(
          status: MyTripsStatus.ready,
          trips: page.items,
          totalCount: page.totalCount,
        ),
      );
    } catch (error) {
      if (generation != _generation || isClosed) return;
      emit(
        MyTripsState(
          status: MyTripsStatus.failure,
          trips: state.trips,
          totalCount: state.totalCount,
          message: error is Failure ? error.message : _unavailableMessage,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.status != MyTripsStatus.ready ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    emit(
      MyTripsState(
        status: MyTripsStatus.ready,
        trips: current.trips,
        totalCount: current.totalCount,
        isLoadingMore: true,
      ),
    );
    try {
      final next = await _repository.listMine(
        page: _page + 1,
        pageSize: pageSize,
      );
      if (generation != _generation || isClosed) return;
      _page++;
      final knownIds = current.trips.map((trip) => trip.itineraryId).toSet();
      emit(
        MyTripsState(
          status: MyTripsStatus.ready,
          trips: [
            ...current.trips,
            ...next.items.where((trip) => knownIds.add(trip.itineraryId)),
          ],
          totalCount: next.totalCount,
        ),
      );
    } catch (_) {
      if (generation != _generation || isClosed) return;
      emit(
        MyTripsState(
          status: MyTripsStatus.ready,
          trips: current.trips,
          totalCount: current.totalCount,
        ),
      );
    }
  }
}
