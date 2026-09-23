import 'package:equatable/equatable.dart';

final class PoiLocation extends Equatable {
  const PoiLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}
