import 'package:equatable/equatable.dart';

/// Fee charged when a booking is cancelled at least [daysBeforeDeparture] days
/// before departure and later than the next longer rule.
final class TourCancellationRule extends Equatable {
  const TourCancellationRule({
    required this.daysBeforeDeparture,
    required this.feePercent,
  });

  final int daysBeforeDeparture;
  final double feePercent;

  @override
  List<Object?> get props => [daysBeforeDeparture, feePercent];
}
