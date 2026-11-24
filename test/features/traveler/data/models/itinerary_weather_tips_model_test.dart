import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_weather_tips_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

Map<String, Object?> _tips({
  Object? date = '2026-11-25',
  Object? timeZoneId = 'Asia/Ho_Chi_Minh',
  Object? forecastAtUtc = '2026-11-24T03:00:00Z',
  Object? summary = const {
    'minTempC': 22,
    'maxTempC': 31,
    'maxRainProbabilityPercent': 60,
    'maxUvIndex': 8,
  },
  Object? tips = const [
    {
      'code': 'weather_tip.storm',
      'severity': 'Warning',
      'text': 'Có dông hoặc mưa to, cân nhắc đổi sang điểm trong nhà',
    },
    {
      'code': 'weather_tip.rain',
      'severity': 'Info',
      'text': 'Mang ô hoặc áo mưa',
    },
  ],
}) => {
  'weatherTips': {
    'date': date,
    'timeZoneId': timeZoneId,
    'forecastAtUtc': forecastAtUtc,
    'summary': summary,
    'tips': tips,
  },
};

void main() {
  group('ItineraryWeatherTipsModel.tryParse', () {
    test('parses a full payload', () {
      final result = ItineraryWeatherTipsModel.tryParse(_tips());

      expect(result, isNotNull);
      expect(result!.date, '2026-11-25');
      expect(result.timeZoneId, 'Asia/Ho_Chi_Minh');
      expect(result.forecastAtUtc, DateTime.utc(2026, 11, 24, 3));
      expect(
        result.summary,
        const WeatherTipsSummary(
          minTempC: 22,
          maxTempC: 31,
          maxRainProbabilityPercent: 60,
          maxUvIndex: 8,
        ),
      );
      expect(result.tips, const [
        WeatherTip(
          code: 'weather_tip.storm',
          severity: WeatherTipSeverity.warning,
          text: 'Có dông hoặc mưa to, cân nhắc đổi sang điểm trong nhà',
        ),
        WeatherTip(
          code: 'weather_tip.rain',
          severity: WeatherTipSeverity.info,
          text: 'Mang ô hoặc áo mưa',
        ),
      ]);
    });

    test('parses empty tips', () {
      final result = ItineraryWeatherTipsModel.tryParse(_tips(tips: const []));

      expect(result, isNotNull);
      expect(result!.tips, isEmpty);
    });

    test('accepts whole-number doubles in the summary', () {
      final result = ItineraryWeatherTipsModel.tryParse(
        _tips(
          summary: const {
            'minTempC': 22.0,
            'maxTempC': 31.0,
            'maxRainProbabilityPercent': 60.0,
            'maxUvIndex': 8.0,
          },
        ),
      );

      expect(result?.summary.minTempC, 22);
      expect(result?.summary.maxUvIndex, 8);
    });

    test('returns null when the backend has nothing', () {
      expect(
        ItineraryWeatherTipsModel.tryParse(const {'weatherTips': null}),
        isNull,
      );
      expect(ItineraryWeatherTipsModel.tryParse(null), isNull);
      expect(ItineraryWeatherTipsModel.tryParse('weatherTips'), isNull);
      expect(
        ItineraryWeatherTipsModel.tryParse(const <String, Object?>{}),
        isNull,
      );
    });

    final malformed = <String, Map<String, Object?>>{
      'summary missing': _tips(summary: null),
      'a summary field is a string': _tips(
        summary: const {
          'minTempC': 22,
          'maxTempC': 31,
          'maxRainProbabilityPercent': 60,
          'maxUvIndex': '8',
        },
      ),
      'a summary field is a fraction': _tips(
        summary: const {
          'minTempC': 22.5,
          'maxTempC': 31,
          'maxRainProbabilityPercent': 60,
          'maxUvIndex': 8,
        },
      ),
      'tips is not a list': _tips(tips: 'Mang ô'),
      'a tip lacks text': _tips(
        tips: const [
          {'code': 'x', 'severity': 'Info'},
        ],
      ),
      'a tip severity is unknown': _tips(
        tips: const [
          {'code': 'x', 'severity': 'Critical', 'text': 'y'},
        ],
      ),
      'a tip is not a map': _tips(tips: const ['Mang ô']),
      'date has another format': _tips(date: '25/11/2026'),
      'date is not a string': _tips(date: 20261125),
      'timeZoneId is not a string': _tips(timeZoneId: 7),
      'forecastAtUtc is not a date': _tips(forecastAtUtc: 'yesterday'),
    };
    for (final entry in malformed.entries) {
      test('returns null when ${entry.key}', () {
        expect(ItineraryWeatherTipsModel.tryParse(entry.value), isNull);
      });
    }
  });

  group('ItineraryWeatherTips.dayAndMonth', () {
    ItineraryWeatherTips withDate(String date) => ItineraryWeatherTips(
      date: date,
      timeZoneId: 'Asia/Ho_Chi_Minh',
      forecastAtUtc: DateTime.utc(2026, 11, 24),
      summary: const WeatherTipsSummary(
        minTempC: 1,
        maxTempC: 2,
        maxRainProbabilityPercent: 3,
        maxUvIndex: 4,
      ),
      tips: const [],
    );

    test('is day/month taken from the string', () {
      expect(withDate('2026-11-25').dayAndMonth, '25/11');
      expect(withDate('2026-12-01').dayAndMonth, '01/12');
    });
  });
}
