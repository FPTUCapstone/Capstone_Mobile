import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';

/// UC-10: when the detail is loaded again after a create that answered
/// `explanationPending: true`, counted from the create (BE spec section 6).
const explanationRefreshDelays = <Duration>[
  Duration(seconds: 20),
  Duration(seconds: 45),
  Duration(seconds: 75),
  Duration(seconds: 110),
];

/// True when some stop has a non-empty sentence that differs from its template
/// sentence: the AI has written at least one explanation.
bool hasNewExplanation(
  Map<int, String> template,
  List<ItineraryDetailItem> items,
) => items.any((item) {
  final sentence = item.friendlyExplanation?.trim();
  return sentence != null &&
      sentence.isNotEmpty &&
      sentence != (template[item.sequenceNo] ?? '');
});

/// Takes only `friendlyExplanation` from [fresh], matched by `sequenceNo`, so
/// nothing else on the page is overwritten. Returns [current] itself when
/// nothing changes.
ItineraryDetail mergeExplanations(
  ItineraryDetail current,
  ItineraryDetail fresh,
) {
  final freshBySequence = <int, String>{};
  for (final item in fresh.items) {
    final sentence = item.friendlyExplanation?.trim();
    if (sentence != null && sentence.isNotEmpty) {
      freshBySequence[item.sequenceNo] = sentence;
    }
  }

  var changed = false;
  final items = <ItineraryDetailItem>[];
  for (final item in current.items) {
    final sentence = freshBySequence[item.sequenceNo];
    if (sentence == null || sentence == item.friendlyExplanation) {
      items.add(item);
    } else {
      changed = true;
      items.add(item.withFriendlyExplanation(sentence));
    }
  }
  return changed ? current.withItems(items) : current;
}
