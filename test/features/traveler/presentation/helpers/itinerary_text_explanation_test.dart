import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';

void main() {
  group('stopExplanationText (UC-10)', () {
    test('prefers the AI sentence over the recommendation reason', () {
      expect(
        stopExplanationText(
          friendlyExplanation: 'AI sentence',
          recommendationReason: 'Template reason',
        ),
        'AI sentence',
      );
    });

    for (final blank in <String?>[null, '', '   ', '\n\t']) {
      test('falls back to the reason when friendlyExplanation is $blank', () {
        expect(
          stopExplanationText(
            friendlyExplanation: blank,
            recommendationReason: 'Template reason',
          ),
          'Template reason',
        );
      });
    }

    test('returns null when both are missing or only whitespace', () {
      expect(stopExplanationText(), isNull);
      expect(
        stopExplanationText(
          friendlyExplanation: '  ',
          recommendationReason: ' ',
        ),
        isNull,
      );
    });

    test('trims the sentence it returns', () {
      expect(
        stopExplanationText(friendlyExplanation: '  AI sentence  '),
        'AI sentence',
      );
      expect(
        stopExplanationText(recommendationReason: ' Template reason '),
        'Template reason',
      );
    });
  });
}
