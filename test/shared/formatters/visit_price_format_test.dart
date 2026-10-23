import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/data/models/cost_kind_json.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

void main() {
  group('parseCostKind', () {
    test('reads the backend names', () {
      expect(parseCostKind('AdmissionTicket'), CostKind.admissionTicket);
      expect(parseCostKind('AverageSpend'), CostKind.averageSpend);
    });

    test('returns null for missing or unknown values', () {
      expect(parseCostKind(null), isNull);
      expect(parseCostKind('Other'), isNull);
      expect(parseCostKind(1), isNull);
    });
  });

  group('visitPriceLabel', () {
    test('unknown price is never shown as free', () {
      expect(
        visitPriceLabel(null, CostKind.admissionTicket),
        'Chưa có thông tin',
      );
      expect(visitPriceLabel(null, CostKind.averageSpend), 'Chưa có thông tin');
    });

    test('zero is free', () {
      expect(visitPriceLabel(0, CostKind.admissionTicket), 'Miễn phí');
      expect(visitPriceLabel(0, CostKind.averageSpend), 'Miễn phí');
    });

    test('attraction shows the expected ticket price per person', () {
      expect(
        visitPriceLabel(150000, CostKind.admissionTicket),
        'Giá vé dự kiến: 150.000 VNĐ/người',
      );
    });

    test('food shows the expected spend per person', () {
      expect(
        visitPriceLabel(85000, CostKind.averageSpend),
        'Mức chi tiêu dự kiến: 85.000 VNĐ/người',
      );
    });

    test('a missing cost kind is treated as an admission ticket', () {
      expect(visitPriceLabel(20000, null), 'Giá vé dự kiến: 20.000 VNĐ/người');
    });
  });

  test('formatVnd groups thousands with dots', () {
    expect(formatVnd(0), '0 VNĐ');
    expect(formatVnd(999), '999 VNĐ');
    expect(formatVnd(1250000), '1.250.000 VNĐ');
    expect(formatVnd(1234.6), '1.235 VNĐ');
  });
}
