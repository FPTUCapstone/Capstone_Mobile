import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/resources/public_search_copy.dart';

void main() {
  test('device language is used only without a supported saved preference', () {
    expect(publicSearchUsesEnglish(null, 'vi'), false);
    expect(publicSearchUsesEnglish(null, 'en'), true);
    expect(publicSearchUsesEnglish(null, 'fr'), true);
    expect(publicSearchUsesEnglish('en', 'vi'), true);
    expect(publicSearchUsesEnglish('vi', 'en'), false);
  });
  test('resolves selected copy, EN fallback and safe missing copy', () {
    const en = {SearchText.title: 'Search tours', SearchText.retry: 'Retry'};
    const vi = {SearchText.title: 'Tìm tour'};
    String resolve(SearchText key, bool english) =>
        resolveSearchCopy(key, english, english: en, vietnamese: vi);
    expect(resolve(SearchText.title, false), 'Tìm tour');
    expect(resolve(SearchText.title, true), 'Search tours');
    expect(resolve(SearchText.retry, false), 'Retry');
    expect(resolve(SearchText.emptyTitle, false), '—');
    expect(vi, {SearchText.title: 'Tìm tour'});
    expect(en, {SearchText.title: 'Search tours', SearchText.retry: 'Retry'});
  });

  test('clear-date accessibility copy follows selected language', () {
    expect(publicSearchClearDate('Đến ngày', false), 'Xóa Đến ngày');
    expect(publicSearchClearDate('To date', true), 'Clear To date');
  });
  test('every public Search key renders copy in both locales', () {
    for (final key in SearchText.values) {
      for (final english in [true, false]) {
        final text = publicSearchCopy(key, english);
        expect(text.trim(), isNotEmpty, reason: '$key');
        expect(text, isNot(key.name), reason: '$key');
      }
    }
  });
}
