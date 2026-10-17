import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/demo_tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/pending_tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/repositories/tour_detail_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class TourDetailCubit extends Cubit<TourDetailState> {
  TourDetailCubit({
    GetTourDetail? getTourDetail,
    TourSummary? initialSummary,
    this.isDemoMode = false,
  }) : _getTourDetail =
           getTourDetail ??
           (isDemoMode
               ? const GetTourDetail(
                   TourDetailRepositoryImpl(DemoTourDetailDataSource()),
                 )
               : (serviceLocator.isRegistered<GetTourDetail>()
                     ? serviceLocator<GetTourDetail>()
                     : const GetTourDetail(
                         TourDetailRepositoryImpl(
                           PendingTourDetailDataSource(),
                         ),
                       ))),
       super(
         TourDetailState.initial(
           initialSummary: initialSummary,
           isDemoMode: isDemoMode,
         ),
       );

  final GetTourDetail _getTourDetail;
  final bool isDemoMode;

  Future<void> load(String tourId) async {
    emit(
      TourDetailState.loading(
        initialSummary: state.initialSummary,
        isDemoMode: isDemoMode,
      ),
    );
    try {
      final detail = await _getTourDetail(
        tourId,
        initialSummary: state.initialSummary,
      );
      if (detail == null) {
        emit(
          TourDetailState.error(
            TourDetailState.notFoundMessage,
            failureKind: TourDetailFailureKind.notFound,
            initialSummary: state.initialSummary,
            isDemoMode: isDemoMode,
          ),
        );
        return;
      }
      final firstSelectable = detail.schedules
          .where((schedule) => schedule.isSelectable)
          .firstOrNull;
      emit(
        TourDetailState.success(
          tourDetail: detail,
          initialSummary: state.initialSummary,
          selectedScheduleId: firstSelectable?.scheduleId,
          // Departures exist but none can be booked: say so (MSG65) instead of
          // leaving a silently disabled Book Now.
          scheduleError: detail.schedules.isNotEmpty && firstSelectable == null
              ? TourDetailState.msg65
              : null,
          isDemoMode: isDemoMode,
        ),
      );
    } on TourDetailIntegrationPendingException {
      emit(
        TourDetailState.pendingIntegration(
          initialSummary: state.initialSummary,
          isDemoMode: false,
        ),
      );
    } on Object {
      emit(
        TourDetailState.error(
          TourDetailState.msg127,
          initialSummary: state.initialSummary,
          isDemoMode: isDemoMode,
        ),
      );
    }
  }

  void selectSchedule(String scheduleId) {
    final detail = state.tourDetail;
    if (detail == null) return;
    final schedule = detail.schedules.cast<TourScheduleItem?>().firstWhere(
      (item) => item?.scheduleId == scheduleId,
      orElse: () => null,
    );
    if (schedule == null) return;
    emit(
      state.copyWith(
        selectedScheduleId: scheduleId,
        scheduleError: schedule.isSelectable ? null : TourDetailState.msg65,
        clearScheduleError: schedule.isSelectable,
      ),
    );
  }

  void simulateNoReviews() {
    if (!isDemoMode || state.tourDetail == null) return;
    emit(
      state.copyWith(
        tourDetail: _copyDetail(
          state.tourDetail!,
          reviews: const [],
          reviewCount: 0,
        ),
      ),
    );
  }

  void simulateSoldOut() {
    if (!isDemoMode || state.tourDetail == null) return;
    final current = state.tourDetail!;
    final schedules = current.schedules
        .map(
          (schedule) => TourScheduleItem(
            scheduleId: schedule.scheduleId,
            departureAtUtc: schedule.departureAtUtc,
            price: schedule.price,
            currency: schedule.currency,
            remainingSlots: 0,
            totalSlots: schedule.totalSlots,
            availabilityStatus: AvailabilityStatus.soldOut,
            endAtUtc: schedule.endAtUtc,
            meetingPoint: schedule.meetingPoint,
            registrationDeadlineUtc: schedule.registrationDeadlineUtc,
            childPrice: schedule.childPrice,
            infantPrice: schedule.infantPrice,
            bookable: false,
          ),
        )
        .toList();
    emit(
      state.copyWith(
        tourDetail: _copyDetail(current, schedules: schedules),
        selectedScheduleId: schedules.firstOrNull?.scheduleId,
        scheduleError: TourDetailState.msg65,
      ),
    );
  }

  void simulateError() {
    if (!isDemoMode) return;
    emit(
      TourDetailState.error(
        TourDetailState.msg127,
        initialSummary: state.initialSummary,
        isDemoMode: true,
      ),
    );
  }

  static TourDetail _copyDetail(
    TourDetail detail, {
    List<TourScheduleItem>? schedules,
    List<TourReviewItem>? reviews,
    int? reviewCount,
  }) => TourDetail(
    tourId: detail.tourId,
    title: detail.title,
    description: detail.description,
    destinations: detail.destinations,
    durationDays: detail.durationDays,
    operatorName: detail.operatorName,
    operatorPhone: detail.operatorPhone,
    operatorEmail: detail.operatorEmail,
    basePrice: detail.basePrice,
    currency: detail.currency,
    images: detail.images,
    inclusions: detail.inclusions,
    exclusions: detail.exclusions,
    cancellationPolicy: detail.cancellationPolicy,
    itineraryDays: detail.itineraryDays,
    schedules: schedules ?? detail.schedules,
    reviews: reviews ?? detail.reviews,
    averageRating: reviews?.isEmpty == true ? null : detail.averageRating,
    reviewCount: reviewCount ?? detail.reviewCount,
    destinationSummary: detail.destinationSummary,
    cancellationRules: detail.cancellationRules,
    hasBookableSchedule: detail.hasBookableSchedule,
    asOfUtc: detail.asOfUtc,
  );
}
