/// TourAPI contentTypeId 기반 카테고리.
/// tourSpots 백필 대상은 이 7종뿐이다 (scripts/backfill/config.ts의 contentTypeIds).
/// "여행코스"(25)는 아직 백엔드에서 동기화하지 않아 제외했다.
enum TourCategory {
  touristSpot,
  cultureFacility,
  festival,
  leports,
  lodging,
  shopping,
  restaurant,
}

extension TourCategoryX on TourCategory {
  String get contentTypeId => switch (this) {
    TourCategory.touristSpot => '12',
    TourCategory.cultureFacility => '14',
    TourCategory.festival => '15',
    TourCategory.leports => '28',
    TourCategory.lodging => '32',
    TourCategory.shopping => '38',
    TourCategory.restaurant => '39',
  };

  String get label => switch (this) {
    TourCategory.touristSpot => '여행지',
    TourCategory.cultureFacility => '문화시설',
    TourCategory.festival => '축제/공연/행사',
    TourCategory.leports => '레포츠',
    TourCategory.lodging => '숙박',
    TourCategory.shopping => '쇼핑',
    TourCategory.restaurant => '음식점',
  };
}
