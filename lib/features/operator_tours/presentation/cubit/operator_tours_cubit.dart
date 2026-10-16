import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';

enum OperatorToursStatus { loading, ready, failure }

final class OperatorToursState extends Equatable {
  const OperatorToursState({
    this.status = OperatorToursStatus.loading,
    this.items = const [],
    this.filter,
    this.page = 0,
    this.totalCount = 0,
    this.loadingMore = false,
    this.failure,
  });
  final OperatorToursStatus status;
  final List<TourPackageSummary> items;

  /// Null shows every status.
  final TourPackageStatus? filter;
  final int page;
  final int totalCount;
  final bool loadingMore;
  final Failure? failure;

  bool get hasMore => items.length < totalCount;

  @override
  List<Object?> get props => [
    status,
    items,
    filter,
    page,
    totalCount,
    loadingMore,
    failure,
  ];
}

/// The operator's own tour packages, filtered by status on the server and paged.
final class OperatorToursCubit extends Cubit<OperatorToursState> {
  OperatorToursCubit({required ListTourPackagesUseCase listTours})
    : _listTours = listTours,
      super(const OperatorToursState());
  final ListTourPackagesUseCase _listTours;

  Future<void> load({TourPackageStatus? filter}) async {
    emit(OperatorToursState(filter: filter));
    try {
      final result = await _listTours(status: filter?.apiName, page: 1);
      if (isClosed) return;
      emit(
        OperatorToursState(
          status: OperatorToursStatus.ready,
          items: result.items,
          filter: filter,
          page: result.page,
          totalCount: result.totalCount,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          OperatorToursState(
            status: OperatorToursStatus.failure,
            filter: filter,
            failure: failure,
          ),
        );
      }
    }
  }

  Future<void> refresh() => load(filter: state.filter);

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != OperatorToursStatus.ready) {
      return;
    }
    final filter = state.filter;
    emit(
      OperatorToursState(
        status: state.status,
        items: state.items,
        filter: filter,
        page: state.page,
        totalCount: state.totalCount,
        loadingMore: true,
      ),
    );
    try {
      final result = await _listTours(
        status: filter?.apiName,
        page: state.page + 1,
      );
      if (isClosed || state.filter != filter) return;
      emit(
        OperatorToursState(
          status: OperatorToursStatus.ready,
          items: [...state.items, ...result.items],
          filter: filter,
          page: result.page,
          totalCount: result.totalCount,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed && state.filter == filter) {
        emit(
          OperatorToursState(
            status: OperatorToursStatus.ready,
            items: state.items,
            filter: filter,
            page: state.page,
            totalCount: state.totalCount,
            failure: failure,
          ),
        );
      }
    }
  }
}
