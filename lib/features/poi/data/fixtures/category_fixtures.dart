// FIXTURE: category preview only. These IDs must never be used in production
// until the backend publishes an approved category catalogue.
const poiCategoryPreviewFixtures = <PoiCategoryFixture>[
  PoiCategoryFixture(id: 1, name: 'Di sản & Danh thắng'),
  PoiCategoryFixture(id: 2, name: 'Bãi biển'),
  PoiCategoryFixture(id: 3, name: 'Thiên nhiên'),
  PoiCategoryFixture(id: 4, name: 'Bảo tàng'),
];

final class PoiCategoryFixture {
  const PoiCategoryFixture({required this.id, required this.name});

  final int id;
  final String name;
}
