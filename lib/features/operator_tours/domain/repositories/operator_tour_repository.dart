import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';

abstract interface class OperatorTourRepository {
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey);
}
