/// 자주 묻는 질문의 대분류.
enum FaqCategory {
  accessibilityProfile,
  explore,
  savedSpot,
  etc,
}

extension FaqCategoryX on FaqCategory {
  String get label => switch (this) {
    FaqCategory.accessibilityProfile => '접근성 프로필',
    FaqCategory.explore => '탐색',
    FaqCategory.savedSpot => '저장',
    FaqCategory.etc => '기타',
  };
}
