/// TourAPI contentTypeId 기반 카테고리 (통합필터선택 - 카테고리)
/// 선택된 카테고리가 없으면 필터링 자체가 적용되지 않음
/// (explore_screen.dart _selectedCategories.isNotEmpty 체크)
/// 해당 타입 스팟도 기본 검색 결과에는 계속 나옴

enum TourCategory {
  touristSpot,
  cultureFacility,
  leports,
  lodging,
  shopping,
  restaurant,
}

extension TourCategoryX on TourCategory {
  String get contentTypeId => switch (this) {
    TourCategory.touristSpot => '12',
    TourCategory.cultureFacility => '14',
    TourCategory.leports => '28',
    TourCategory.lodging => '32',
    TourCategory.shopping => '38',
    TourCategory.restaurant => '39',
  };

  String get label => switch (this) {
    TourCategory.touristSpot => '여행지',
    TourCategory.cultureFacility => '문화시설',
    TourCategory.leports => '레포츠',
    TourCategory.lodging => '숙박',
    TourCategory.shopping => '쇼핑',
    TourCategory.restaurant => '음식점',
  };
}
