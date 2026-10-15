import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/mapbox_search_box_model.dart';

Map<String, dynamic> searchBoxSuggestion({
  String? id = 'poi.fpt-da-nang',
  String? name = 'Đại học FPT Đà Nẵng',
  String featureType = 'poi',
  String? fullAddress = 'Đào Tấn, Đà Nẵng, 50500, Việt Nam',
  String? placeFormatted,
}) => {
  'mapbox_id': id,
  'name': name,
  'feature_type': featureType,
  'full_address': fullAddress,
  'place_formatted': placeFormatted,
};

Map<String, dynamic> searchBoxFeature({
  String? name = 'Đại học FPT Đà Nẵng',
  String? fullAddress = 'Đào Tấn, Đà Nẵng, 50500, Việt Nam',
  List<Object> coordinates = const [108.26072704, 15.96862121],
}) => {
  'type': 'Feature',
  'geometry': {'type': 'Point', 'coordinates': coordinates},
  'properties': {'name': name, 'full_address': fullAddress},
};

void main() {
  test('suggestions keep locations and drop categories and brands', () {
    final candidates = MapboxSearchBoxModel.suggestions({
      'suggestions': [
        searchBoxSuggestion(
          id: 'category.university',
          name: 'Đại học',
          featureType: 'category',
        ),
        searchBoxSuggestion(),
        searchBoxSuggestion(id: 'brand.fpt', name: 'FPT', featureType: 'brand'),
        searchBoxSuggestion(
          id: 'street.bach-dang',
          name: 'Đường Bạch Đằng',
          featureType: 'street',
          fullAddress: null,
          placeFormatted: 'Phước Ninh, 50200, Hai Chau, Đà Nẵng, Việt Nam',
        ),
        searchBoxSuggestion(id: null),
      ],
    });

    expect(candidates.map((candidate) => candidate.id), [
      'poi.fpt-da-nang',
      'street.bach-dang',
    ]);
    expect(
      candidates.last.fullAddress,
      'Phước Ninh, 50200, Hai Chau, Đà Nẵng, Việt Nam',
    );
  });

  test('the ward from the context is shown after the street', () {
    final candidates = MapboxSearchBoxModel.suggestions({
      'suggestions': [
        {
          ...searchBoxSuggestion(),
          'context': {
            'neighborhood': {'name': 'Hòa Hải'},
            'place': {'name': 'Đà Nẵng'},
          },
        },
        {
          ...searchBoxSuggestion(
            id: 'poi.already-has-ward',
            fullAddress: 'Hòa Hải, Đà Nẵng, Việt Nam',
          ),
          'context': {
            'neighborhood': {'name': 'Hòa Hải'},
          },
        },
      ],
    });

    expect(
      candidates.first.fullAddress,
      'Đào Tấn, Hòa Hải, Đà Nẵng, 50500, Việt Nam',
    );
    expect(candidates.last.fullAddress, 'Hòa Hải, Đà Nẵng, Việt Nam');
  });

  test('a retrieved place has its point with longitude first', () {
    final place = MapboxSearchBoxModel.retrieved({
      'features': [searchBoxFeature()],
    });

    expect(place.latitude, 15.96862121);
    expect(place.longitude, 108.26072704);
    expect(
      place.label,
      'Đại học FPT Đà Nẵng, Đào Tấn, Đà Nẵng, 50500, Việt Nam',
    );
  });

  test('a street label does not repeat its name', () {
    final place = MapboxSearchBoxModel.retrieved({
      'features': [
        searchBoxFeature(
          name: 'Đường Bạch Đằng',
          fullAddress: 'Đường Bạch Đằng, Phước Ninh, Đà Nẵng, Việt Nam',
        ),
      ],
    });

    expect(place.label, 'Đường Bạch Đằng, Phước Ninh, Đà Nẵng, Việt Nam');
  });

  test('malformed responses are rejected', () {
    expect(
      () => MapboxSearchBoxModel.suggestions({'type': 'x'}),
      throwsFormatException,
    );
    expect(
      () => MapboxSearchBoxModel.retrieved({
        'features': [
          searchBoxFeature(coordinates: const [108.2]),
        ],
      }),
      throwsFormatException,
    );
  });
}
