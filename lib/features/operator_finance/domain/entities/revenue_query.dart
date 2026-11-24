import 'package:equatable/equatable.dart';

/// Reporting dates are calendar dates in Vietnam, not instants to convert.
final class RevenueQuery extends Equatable {
  RevenueQuery({
    required DateTime startDate,
    required DateTime endDate,
    this.granularity = 'monthly',
    this.tourId,
    this.page = 1,
    this.pageSize = 10,
  }) : startDate = DateTime(startDate.year, startDate.month, startDate.day),
       endDate = DateTime(endDate.year, endDate.month, endDate.day);

  final DateTime startDate;
  final DateTime endDate;
  final String granularity;
  final int? tourId;
  final int page;
  final int pageSize;

  String? get validationError {
    if (startDate.isAfter(endDate)) {
      return 'Ngày kết thúc phải từ ngày bắt đầu trở đi.';
    }
    if (!const ['daily', 'weekly', 'monthly'].contains(granularity)) {
      return 'Vui lòng chọn cách nhóm kỳ hợp lệ.';
    }
    if (tourId != null && tourId! <= 0) {
      return 'Vui lòng chọn tour hợp lệ.';
    }
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      return 'Thông tin trang không hợp lệ.';
    }
    return null;
  }

  bool get isValid => validationError == null;

  RevenueQuery copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? granularity,
    int? tourId,
    bool clearTour = false,
    int? page,
    int? pageSize,
  }) => RevenueQuery(
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    granularity: granularity ?? this.granularity,
    tourId: clearTour ? null : tourId ?? this.tourId,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );

  @override
  List<Object?> get props => [
    startDate,
    endDate,
    granularity,
    tourId,
    page,
    pageSize,
  ];
}
