import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_list_card.dart';

void main() {
  group('TourListCard', () {
    testWidgets('renders tour details correctly for available tour', (
      tester,
    ) async {
      final tour = TourSummary(
        tourId: '101',
        title: 'Tour Đà Nẵng – Hội An 3N2Đ',
        destinations: const ['Đà Nẵng', 'Hội An'],
        operatorName: 'Công ty Du lịch Miền Trung',
        durationDays: 3,
        basePrice: 1500000,
        currency: 'VND',
        representativeScheduleId: '201',
        departureAtUtc: DateTime.utc(2026, 10, 1, 1, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TourListCard(tour: tour)),
        ),
      );

      expect(find.text('Tour Đà Nẵng – Hội An 3N2Đ'), findsOneWidget);
      expect(find.text('Đà Nẵng • Hội An'), findsOneWidget);
      expect(find.text('Công ty Du lịch Miền Trung'), findsOneWidget);
      expect(find.text('3 ngày'), findsOneWidget);
      expect(find.text('1.500.000₫'), findsOneWidget);
      expect(find.textContaining('Còn 6 chỗ'), findsOneWidget);
      expect(find.textContaining('01/10/2026'), findsOneWidget);
    });

    testWidgets('renders soldOut badge when tour is sold out', (tester) async {
      const tour = TourSummary(
        tourId: '102',
        title: 'Tour Huế di sản',
        destinations: ['Huế'],
        operatorName: 'Hue Travel',
        durationDays: 1,
        basePrice: 450000,
        currency: 'VND',
        representativeScheduleId: '202',
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.soldOut,
        remainingSlots: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TourListCard(tour: tour)),
        ),
      );

      expect(find.text('Hết chỗ'), findsOneWidget);
    });

    testWidgets('renders noUpcomingSchedule badge when tour has no schedule', (
      tester,
    ) async {
      const tour = TourSummary(
        tourId: '103',
        title: 'Tour Phong Nha',
        destinations: ['Quảng Bình'],
        operatorName: 'Cave Explorer',
        durationDays: 2,
        basePrice: 2000000,
        currency: 'VND',
        representativeScheduleId: null,
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.noUpcomingSchedule,
        remainingSlots: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TourListCard(tour: tour)),
        ),
      );

      expect(find.text('Chưa có lịch khởi hành'), findsOneWidget);
    });

    testWidgets('renders unknown badge when capacity is corrupted', (
      tester,
    ) async {
      const tour = TourSummary(
        tourId: '104',
        title: 'Tour Cù Lao Chàm',
        destinations: ['Quảng Nam'],
        operatorName: 'Island Tour',
        durationDays: 1,
        basePrice: 650000,
        currency: 'VND',
        representativeScheduleId: null,
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.unknown,
        remainingSlots: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TourListCard(tour: tour)),
        ),
      );

      expect(find.text('Tình trạng chỗ chưa xác định'), findsOneWidget);
    });

    testWidgets('formats non-VND currency with currency code', (tester) async {
      const tour = TourSummary(
        tourId: '105',
        title: 'International Tour',
        destinations: ['Đà Nẵng'],
        operatorName: 'Global Travel',
        durationDays: 4,
        basePrice: 1200,
        currency: 'USD',
        representativeScheduleId: null,
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TourListCard(tour: tour)),
        ),
      );

      expect(find.text('1.200 USD'), findsOneWidget);
    });

    group('TM-209 Thumbnail Integration', () {
      testWidgets(
        'renders real network Tour image with semantic label when thumbnailUrl is present',
        (tester) async {
          final tour = TourSummary(
            tourId: '201',
            title: 'Tour Hội An Phố Cổ',
            destinations: const ['Hội An'],
            operatorName: 'An Travel',
            durationDays: 1,
            basePrice: 500000,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 5,
            thumbnailUrl: 'https://example.com/hoian.jpg',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: TourListCard(tour: tour)),
            ),
          );

          expect(find.byType(Image), findsOneWidget);
          final imageWidget = tester.widget<Image>(find.byType(Image));
          expect(imageWidget.image, isA<NetworkImage>());
          expect(
            (imageWidget.image as NetworkImage).url,
            'https://example.com/hoian.jpg',
          );
          expect(imageWidget.semanticLabel, 'Ảnh Tour Hội An Phố Cổ');
          expect(imageWidget.fit, BoxFit.cover);
          expect(find.byIcon(Icons.image_outlined), findsNothing);
        },
      );

      testWidgets(
        'renders neutral placeholder and no Image when thumbnailUrl is null',
        (tester) async {
          const tour = TourSummary(
            tourId: '202',
            title: 'Tour Ngũ Hành Sơn',
            destinations: ['Đà Nẵng'],
            operatorName: 'Danang Travel',
            durationDays: 1,
            basePrice: 300000,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 10,
            thumbnailUrl: null,
          );

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: TourListCard(tour: tour)),
            ),
          );

          expect(find.byType(Image), findsNothing);
          expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        },
      );

      testWidgets(
        'renders neutral placeholder when thumbnailUrl is blank or whitespace',
        (tester) async {
          const tour = TourSummary(
            tourId: '203',
            title: 'Tour Huế',
            destinations: ['Huế'],
            operatorName: 'Hue Travel',
            durationDays: 1,
            basePrice: 400000,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 4,
            thumbnailUrl: '   ',
          );

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: TourListCard(tour: tour)),
            ),
          );

          expect(find.byType(Image), findsNothing);
          expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        },
      );

      testWidgets(
        'network load failure triggers errorBuilder and renders neutral placeholder',
        (tester) async {
          final tour = TourSummary(
            tourId: '204',
            title: 'Tour Cù Lao Chàm',
            destinations: const ['Quảng Nam'],
            operatorName: 'Island Travel',
            durationDays: 1,
            basePrice: 600000,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 8,
            thumbnailUrl: 'https://example.com/broken.jpg',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: TourListCard(tour: tour)),
            ),
          );

          final imageWidget = tester.widget<Image>(find.byType(Image));
          expect(imageWidget.errorBuilder, isNotNull);

          // Invoke the errorBuilder to ensure it returns the neutral placeholder
          final errorWidget = imageWidget.errorBuilder!(
            tester.element(find.byType(Image)),
            Exception('404 Not Found'),
            StackTrace.empty,
          );

          await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: errorWidget)),
          );

          expect(find.byIcon(Icons.image_outlined), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(ExcludeSemantics),
              matching: find.byIcon(Icons.image_outlined),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'decorative placeholder is excluded from semantics to prevent noisy output',
        (tester) async {
          const tour = TourSummary(
            tourId: '205',
            title: 'Tour Phong Nha',
            destinations: ['Quảng Bình'],
            operatorName: 'Cave Travel',
            durationDays: 2,
            basePrice: 1200000,
            currency: 'VND',
            representativeScheduleId: null,
            departureAtUtc: null,
            availabilityStatus: AvailabilityStatus.available,
            remainingSlots: 3,
            thumbnailUrl: null,
          );

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: TourListCard(tour: tour)),
            ),
          );

          // Icon is enclosed within ExcludeSemantics
          final excludedIcon = find.descendant(
            of: find.byType(ExcludeSemantics),
            matching: find.byIcon(Icons.image_outlined),
          );
          expect(excludedIcon, findsOneWidget);
        },
      );
    });
  });
}
