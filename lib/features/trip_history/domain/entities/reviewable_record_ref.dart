import 'package:equatable/equatable.dart';

enum ReviewableRecordKind { commerceBooking, serviceBooking }

final class ReviewableRecordRef extends Equatable {
  const ReviewableRecordRef({required this.kind, required this.id})
    : assert(id > 0);

  final ReviewableRecordKind kind;
  final int id;
  String get apiSegment => kind == ReviewableRecordKind.commerceBooking
      ? 'bookings'
      : 'service-bookings';
  String get wireKind => kind.name;

  @override
  List<Object?> get props => [kind, id];
}
