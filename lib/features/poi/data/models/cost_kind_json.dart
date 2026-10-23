import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';

/// Reads the backend name; unknown or missing values are null.
CostKind? parseCostKind(Object? value) => switch (value) {
  'AdmissionTicket' => CostKind.admissionTicket,
  'AverageSpend' => CostKind.averageSpend,
  _ => null,
};
