import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_search_filter_sheet.dart';

void main() {
  group('TourSearchFilterSheet', () {
    testWidgets('populates initial values and calls onApply with input data', (
      tester,
    ) async {
      String? appliedDestination;
      DateTime? appliedDate;
      int? appliedMinPrice;
      int? appliedMaxPrice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourSearchFilterSheet(
              initialDestination: 'Đà Nẵng',
              initialMinPrice: 200000,
              initialMaxPrice: 1000000,
              onApply:
                  ({
                    String? destination,
                    DateTime? departureDate,
                    int? minPrice,
                    int? maxPrice,
                  }) {
                    appliedDestination = destination;
                    appliedDate = departureDate;
                    appliedMinPrice = minPrice;
                    appliedMaxPrice = maxPrice;
                  },
              onReset: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bộ lọc tìm kiếm'), findsOneWidget);
      expect(find.text('Đà Nẵng'), findsOneWidget);
      expect(find.text('200000'), findsOneWidget);
      expect(find.text('1000000'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng bộ lọc'));
      await tester.pumpAndSettle();

      expect(appliedDestination, 'Đà Nẵng');
      expect(appliedMinPrice, 200000);
      expect(appliedMaxPrice, 1000000);
      expect(appliedDate, isNull);
    });

    testWidgets('shows error when minPrice > maxPrice and does not apply', (
      tester,
    ) async {
      var applied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourSearchFilterSheet(
              initialMinPrice: 5000000,
              initialMaxPrice: 1000000,
              onApply:
                  ({
                    String? destination,
                    DateTime? departureDate,
                    int? minPrice,
                    int? maxPrice,
                  }) {
                    applied = true;
                  },
              onReset: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng bộ lọc'));
      await tester.pumpAndSettle();

      expect(
        find.text('Giá tối thiểu không được lớn hơn giá tối đa.'),
        findsOneWidget,
      );
      expect(applied, isFalse);
    });

    testWidgets('rejects a non-empty price that overflows parsing', (
      tester,
    ) async {
      var applied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourSearchFilterSheet(
              onApply:
                  ({
                    String? destination,
                    DateTime? departureDate,
                    int? minPrice,
                    int? maxPrice,
                  }) {
                    applied = true;
                  },
              onReset: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(1),
        '999999999999999999999999999999',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng bộ lọc'));
      await tester.pumpAndSettle();

      expect(find.text('Giá tối thiểu không hợp lệ.'), findsOneWidget);
      expect(applied, isFalse);
    });

    testWidgets(
      'accepts the backend maximum price and rejects a larger value',
      (tester) async {
        int? appliedMaxPrice;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TourSearchFilterSheet(
                onApply:
                    ({
                      String? destination,
                      DateTime? departureDate,
                      int? minPrice,
                      int? maxPrice,
                    }) {
                      appliedMaxPrice = maxPrice;
                    },
                onReset: () {},
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField).at(2), '9999999999');
        await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng bộ lọc'));
        await tester.pumpAndSettle();
        expect(appliedMaxPrice, 9999999999);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TourSearchFilterSheet(
                onApply:
                    ({
                      String? destination,
                      DateTime? departureDate,
                      int? minPrice,
                      int? maxPrice,
                    }) {},
                onReset: () {},
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField).at(2), '10000000000');
        await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng bộ lọc'));
        await tester.pumpAndSettle();
        expect(
          find.text('Giá tối đa phải từ 0 đến 9.999.999.999 VNĐ.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'opens DatePicker safely when its initial date is in the past',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TourSearchFilterSheet(
                initialDepartureDate: DateTime(2000, 1, 1, 18),
                onApply:
                    ({
                      String? destination,
                      DateTime? departureDate,
                      int? minPrice,
                      int? maxPrice,
                    }) {},
                onReset: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('01/01/2000'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );

    testWidgets('triggers onReset when reset button is tapped', (tester) async {
      var resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourSearchFilterSheet(
              onApply:
                  ({
                    String? destination,
                    DateTime? departureDate,
                    int? minPrice,
                    int? maxPrice,
                  }) {},
              onReset: () {
                resetCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Đặt lại'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
    });
  });
}
