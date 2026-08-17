/// TourAccessibilityInfo(TourAPI 무장애여행 응답)의 개별 편의시설 필드
/// 접근성 유형에 따른 무장애 편의시설 필드
enum AccessibilityField {
  // 지체장애
  parking,
  publicTransport,
  route,
  ticketOffice,
  promotion,
  wheelchair,
  exit,
  elevator,
  restroom,
  auditorium,
  room,
  handicapEtc,

  // 청각장애
  signGuide,
  videoGuide,
  hearingRoom,
  hearingHandicapEtc,

  // 시각장애
  braileBlock,
  helpDog,
  guideHuman,
  audioGuide,
  bigPrint,
  brailePromotion,
  guideSystem,
  blindHandicapEtc,

  // 영유아가족
  stroller,
  lactationRoom,
  babySpareChair,
  infantsFamilyEtc,
}

extension AccessibilityFieldX on AccessibilityField {
  String get label => switch (this) {
    AccessibilityField.parking => '주차 여부',
    AccessibilityField.publicTransport => '대중교통',
    AccessibilityField.route => '접근로',
    AccessibilityField.ticketOffice => '매표소',
    AccessibilityField.promotion => '홍보물',
    AccessibilityField.wheelchair => '휠체어',
    AccessibilityField.exit => '출입통로',
    AccessibilityField.elevator => '엘리베이터',
    AccessibilityField.restroom => '화장실',
    AccessibilityField.auditorium => '관람석',
    AccessibilityField.room => '객실',
    AccessibilityField.handicapEtc => '지체장애 기타사항',
    AccessibilityField.signGuide => '수화 안내',
    AccessibilityField.videoGuide => '자막/영상 안내',
    AccessibilityField.hearingRoom => '청각장애인 객실',
    AccessibilityField.hearingHandicapEtc => '청각장애 기타사항',
    AccessibilityField.braileBlock => '점자블록',
    AccessibilityField.helpDog => '보조견 동반',
    AccessibilityField.guideHuman => '안내요원',
    AccessibilityField.audioGuide => '오디오 가이드',
    AccessibilityField.bigPrint => '큰 활자 홍보물',
    AccessibilityField.brailePromotion => '점자 홍보물',
    AccessibilityField.guideSystem => '유도 안내 설비',
    AccessibilityField.blindHandicapEtc => '시각장애 기타사항',
    AccessibilityField.stroller => '유모차 대여',
    AccessibilityField.lactationRoom => '수유실',
    AccessibilityField.babySpareChair => '유아용 보조의자',
    AccessibilityField.infantsFamilyEtc => '영유아가족 기타사항',
  };
}
