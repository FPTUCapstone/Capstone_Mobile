import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

final class TourSearchQuery extends Equatable {
  const TourSearchQuery({
    this.destination,
    this.departureDate,
    this.minPrice,
    this.maxPrice,
    this.page = 1,
    this.pageSize = 20,
  });

  static const _unset = Object();
  static const int maxDestinationLength = 300;
  static const int minPriceLimit = 0;
  static const int maxPriceLimit = 9999999999;

  final String? destination;
  final DateTime? departureDate;
  final int? minPrice;
  final int? maxPrice;
  final int page;
  final int pageSize;

  Map<String, Object> toQueryParameters() {
    final normalizedDestination = destination?.trim();
    if (normalizedDestination != null &&
        normalizedDestination.length > maxDestinationLength) {
      throw const ValidationFailure(
        'Điểm đến không được vượt quá 300 ký tự.',
        fieldErrors: {
          'destination': ['Điểm đến không được vượt quá 300 ký tự.'],
        },
      );
    }
    if (minPrice != null &&
        (minPrice! < minPriceLimit || minPrice! > maxPriceLimit)) {
      throw const ValidationFailure(
        'Giá tối thiểu phải nằm trong khoảng từ 0 đến 9.999.999.999 VNĐ.',
        fieldErrors: {
          'minPrice': [
            'Giá tối thiểu phải nằm trong khoảng từ 0 đến 9.999.999.999 VNĐ.',
          ],
        },
      );
    }
    if (maxPrice != null &&
        (maxPrice! < minPriceLimit || maxPrice! > maxPriceLimit)) {
      throw const ValidationFailure(
        'Giá tối đa phải nằm trong khoảng từ 0 đến 9.999.999.999 VNĐ.',
        fieldErrors: {
          'maxPrice': [
            'Giá tối đa phải nằm trong khoảng từ 0 đến 9.999.999.999 VNĐ.',
          ],
        },
      );
    }
    if (minPrice != null && maxPrice != null && minPrice! > maxPrice!) {
      throw const ValidationFailure(
        'Giá tối thiểu không được lớn hơn giá tối đa.',
        fieldErrors: {
          'minPrice': ['Giá tối thiểu không được lớn hơn giá tối đa.'],
        },
      );
    }

    final parameters = <String, Object>{
      if (normalizedDestination != null && normalizedDestination.isNotEmpty)
        'destination': normalizedDestination,
      if (departureDate != null) 'departureDate': _formatDate(departureDate!),
      'minPrice': ?minPrice,
      'maxPrice': ?maxPrice,
      'page': page,
      'pageSize': pageSize,
    };
    return parameters;
  }

  TourSearchQuery copyWith({
    Object? destination = _unset,
    Object? departureDate = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    int? page,
    int? pageSize,
  }) {
    return TourSearchQuery(
      destination: identical(destination, _unset)
          ? this.destination
          : destination as String?,
      departureDate: identical(departureDate, _unset)
          ? this.departureDate
          : departureDate as DateTime?,
      minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as int?,
      maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as int?,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
    destination,
    departureDate,
    minPrice,
    maxPrice,
    page,
    pageSize,
  ];
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
