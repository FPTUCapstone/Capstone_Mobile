import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_weather_tips_card.dart';

const _storm = WeatherTip(
  code: 'weather_tip.storm',
  severity: WeatherTipSeverity.warning,
  text: 'Có dông hoặc mưa to, cân nhắc đổi sang điểm trong nhà',
);
const _rain = WeatherTip(
  code: 'weather_tip.rain',
  severity: WeatherTipSeverity.info,
  text: 'Mang ô hoặc áo mưa',
);
const _uv = WeatherTip(
  code: 'weather_tip.uv',
  severity: WeatherTipSeverity.info,
  text: 'Mang kem chống nắng và kính râm',
);

ItineraryWeatherTips _tips({
  String date = '2026-11-25',
  List<WeatherTip> tips = const [_storm, _rain, _uv],
}) => ItineraryWeatherTips(
  date: date,
  timeZoneId: 'Asia/Ho_Chi_Minh',
  forecastAtUtc: DateTime.utc(2026, 11, 24, 3),
  summary: const WeatherTipsSummary(
    minTempC: 22,
    maxTempC: 31,
    maxRainProbabilityPercent: 60,
    maxUvIndex: 8,
  ),
  tips: tips,
);

Future<void> _pump(
  WidgetTester tester,
  ItineraryWeatherTips tips, {
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(child: ItineraryWeatherTipsCard(tips: tips)),
    ),
  ),
);

void main() {
  testWidgets('shows the title with day and month', (tester) async {
    await _pump(tester, _tips());

    expect(find.text('Thời tiết ngày 25/11'), findsOneWidget);
  });

  testWidgets('keeps a first-of-month date on its own day', (tester) async {
    await _pump(tester, _tips(date: '2026-12-01'));

    expect(find.text('Thời tiết ngày 01/12'), findsOneWidget);
  });

  testWidgets('shows the summary line', (tester) async {
    await _pump(tester, _tips());

    expect(find.text('22–31°C · Mưa tối đa 60% · UV 8'), findsOneWidget);
  });

  testWidgets('lists the tips in the received order with the backend text', (
    tester,
  ) async {
    await _pump(tester, _tips());

    final storm = tester.getTopLeft(find.text(_storm.text)).dy;
    final rain = tester.getTopLeft(find.text(_rain.text)).dy;
    final uv = tester.getTopLeft(find.text(_uv.text)).dy;
    expect(storm, lessThan(rain));
    expect(rain, lessThan(uv));
  });

  testWidgets('a Warning tip has the warning icon, an Info tip does not', (
    tester,
  ) async {
    await _pump(tester, _tips());

    final warning = find.byKey(const Key('weather_tip_warning'));
    expect(warning, findsOneWidget);
    expect(
      find.descendant(
        of: warning,
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text(_storm.text), findsOneWidget);
    // Only the Warning row carries the icon; the two Info tips do not.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.descendant(of: warning, matching: find.text(_rain.text)),
      findsNothing,
    );
  });

  testWidgets(
    'shows the empty sentence and no tip rows when there are no tips',
    (tester) async {
      await _pump(tester, _tips(tips: const []));

      expect(
        find.text('Thời tiết thuận lợi, không cần chuẩn bị đặc biệt.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('weather_tip_warning')), findsNothing);
      expect(find.text('22–31°C · Mưa tối đa 60% · UV 8'), findsOneWidget);
    },
  );

  testWidgets('does not show the empty sentence when there are tips', (
    tester,
  ) async {
    await _pump(tester, _tips());

    expect(
      find.text('Thời tiết thuận lợi, không cần chuẩn bị đặc biệt.'),
      findsNothing,
    );
  });

  testWidgets('wraps a long tip at text scale 2.0 on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const long = WeatherTip(
      code: 'weather_tip.storm',
      severity: WeatherTipSeverity.warning,
      text:
          'Có dông hoặc mưa to trong nhiều giờ liền, nên cân nhắc đổi sang '
          'các điểm tham quan trong nhà và mang theo áo mưa gọn nhẹ',
    );

    await _pump(tester, _tips(tips: const [long, _rain]), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text(long.text), findsOneWidget);
  });

  testWidgets('has the semantics label "Gợi ý theo thời tiết"', (tester) async {
    final handle = tester.ensureSemantics();

    await _pump(tester, _tips());

    expect(find.bySemanticsLabel('Gợi ý theo thời tiết'), findsOneWidget);
    handle.dispose();
  });
}
