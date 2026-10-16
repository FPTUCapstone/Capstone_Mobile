import 'package:equatable/equatable.dart';

final class TourCategory extends Equatable {
  const TourCategory({required this.code, required this.name});
  final String code;
  final String name;
  @override
  List<Object> get props => [code, name];
}
