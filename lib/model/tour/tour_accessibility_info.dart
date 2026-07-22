/// detailWithTour2 (무장애여행 조회) 응답 매핑 DTO
library;

class TourAccessibilityInfo {
  final String contentId;

  final PhysicalDisabilityInfo physical; // 지체장애
  final VisualDisabilityInfo visual; // 시각장애
  final HearingDisabilityInfo hearing; // 청각장애
  final InfantFamilyInfo infantFamily; // 영유아가족

  const TourAccessibilityInfo({
    required this.contentId,
    required this.physical,
    required this.visual,
    required this.hearing,
    required this.infantFamily,
  });

  factory TourAccessibilityInfo.fromJson(Map<String, dynamic> json) {
    return TourAccessibilityInfo(
      contentId: json['contentid'].toString(),
      physical: PhysicalDisabilityInfo.fromJson(json),
      visual: VisualDisabilityInfo.fromJson(json),
      hearing: HearingDisabilityInfo.fromJson(json),
      infantFamily: InfantFamilyInfo.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    ...physical.toJson(),
    ...visual.toJson(),
    ...hearing.toJson(),
    ...infantFamily.toJson(),
  };

  /// 4개 그룹 전부 값이 하나도 없으면 true.
  /// (홈 화면 카드에서 "접근성 정보 미제공" 뱃지 처리할 때 씀)
  bool get isEmpty =>
      physical.isEmpty &&
      visual.isEmpty &&
      hearing.isEmpty &&
      infantFamily.isEmpty;
}

String? _emptyToNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// 지체장애 관련 편의시설
class PhysicalDisabilityInfo {
  final String? parking; // 주차 여부
  final String? publicTransport; // 대중교통
  final String? route; // 접근로
  final String? ticketOffice; // 매표소
  final String? promotion; // 홍보물
  final String? wheelchair; // 휠체어
  final String? exit; // 출입통로
  final String? elevator; // 엘리베이터
  final String? restroom; // 화장실
  final String? auditorium; // 관람석
  final String? room; // 객실
  final String? handicapEtc; // 지체장애 기타 상세

  const PhysicalDisabilityInfo({
    this.parking,
    this.publicTransport,
    this.route,
    this.ticketOffice,
    this.promotion,
    this.wheelchair,
    this.exit,
    this.elevator,
    this.restroom,
    this.auditorium,
    this.room,
    this.handicapEtc,
  });

  factory PhysicalDisabilityInfo.fromJson(Map<String, dynamic> json) {
    return PhysicalDisabilityInfo(
      parking: _emptyToNull(json['parking']),
      publicTransport: _emptyToNull(json['publictransport']),
      route: _emptyToNull(json['route']),
      ticketOffice: _emptyToNull(json['ticketoffice']),
      promotion: _emptyToNull(json['promotion']),
      wheelchair: _emptyToNull(json['wheelchair']),
      exit: _emptyToNull(json['exit']),
      elevator: _emptyToNull(json['elevator']),
      restroom: _emptyToNull(json['restroom']),
      auditorium: _emptyToNull(json['auditorium']),
      room: _emptyToNull(json['room']),
      handicapEtc: _emptyToNull(json['handicapetc']),
    );
  }

  Map<String, dynamic> toJson() => {
    'parking': parking,
    'publicTransport': publicTransport,
    'route': route,
    'ticketOffice': ticketOffice,
    'promotion': promotion,
    'wheelchair': wheelchair,
    'exit': exit,
    'elevator': elevator,
    'restroom': restroom,
    'auditorium': auditorium,
    'room': room,
    'handicapEtc': handicapEtc,
  };

  bool get isEmpty =>
      parking == null &&
      publicTransport == null &&
      route == null &&
      ticketOffice == null &&
      promotion == null &&
      wheelchair == null &&
      exit == null &&
      elevator == null &&
      restroom == null &&
      auditorium == null &&
      room == null &&
      handicapEtc == null;
}

/// 시각장애 관련 편의시설
class VisualDisabilityInfo {
  final String? braileBlock; // 점자블록
  final String? helpDog; // 보조견 동반
  final String? guideHuman; // 안내요원
  final String? audioGuide; // 오디오 가이드
  final String? bigPrint; // 큰 활자 홍보물
  final String? brailePromotion; // 점자 홍보물 및 점자표지판
  final String? guideSystem; // 유도 안내 설비
  final String? blindHandicapEtc; // 시각장애 기타상세

  const VisualDisabilityInfo({
    this.braileBlock,
    this.helpDog,
    this.guideHuman,
    this.audioGuide,
    this.bigPrint,
    this.brailePromotion,
    this.guideSystem,
    this.blindHandicapEtc,
  });

  factory VisualDisabilityInfo.fromJson(Map<String, dynamic> json) {
    return VisualDisabilityInfo(
      braileBlock: _emptyToNull(json['braileblock']),
      helpDog: _emptyToNull(json['helpdog']),
      guideHuman: _emptyToNull(json['guidehuman']),
      audioGuide: _emptyToNull(json['audioguide']),
      bigPrint: _emptyToNull(json['bigprint']),
      brailePromotion: _emptyToNull(json['brailepromotion']),
      guideSystem: _emptyToNull(json['guidesystem']),
      blindHandicapEtc: _emptyToNull(json['blindhandicapetc']),
    );
  }

  Map<String, dynamic> toJson() => {
    'braileBlock': braileBlock,
    'helpDog': helpDog,
    'guideHuman': guideHuman,
    'audioGuide': audioGuide,
    'bigPrint': bigPrint,
    'brailePromotion': brailePromotion,
    'guideSystem': guideSystem,
    'blindHandicapEtc': blindHandicapEtc,
  };

  bool get isEmpty =>
      braileBlock == null &&
      helpDog == null &&
      guideHuman == null &&
      audioGuide == null &&
      bigPrint == null &&
      brailePromotion == null &&
      guideSystem == null &&
      blindHandicapEtc == null;
}

/// 청각장애 관련 편의시설
class HearingDisabilityInfo {
  final String? signGuide; // 수화 안내
  final String? videoGuide; // 자막 비디오 가이드 및 영상 자막 안내
  final String? hearingRoom; // 객실
  final String? hearingHandicapEtc; // 청각장애 기타상세

  const HearingDisabilityInfo({
    this.signGuide,
    this.videoGuide,
    this.hearingRoom,
    this.hearingHandicapEtc,
  });

  factory HearingDisabilityInfo.fromJson(Map<String, dynamic> json) {
    return HearingDisabilityInfo(
      signGuide: _emptyToNull(json['signguide']),
      videoGuide: _emptyToNull(json['videoguide']),
      hearingRoom: _emptyToNull(json['hearingroom']),
      hearingHandicapEtc: _emptyToNull(json['hearinghandicapetc']),
    );
  }

  Map<String, dynamic> toJson() => {
    'signGuide': signGuide,
    'videoGuide': videoGuide,
    'hearingRoom': hearingRoom,
    'hearingHandicapEtc': hearingHandicapEtc,
  };

  bool get isEmpty =>
      signGuide == null &&
      videoGuide == null &&
      hearingRoom == null &&
      hearingHandicapEtc == null;
}

/// 영유아가족 관련 편의시설
class InfantFamilyInfo {
  final String? stroller; // 유모차
  final String? lactationRoom; // 수유실
  final String? babySpareChair; // 유아용 보조의자
  final String? infantsFamilyEtc; // 영유아가족 기타상세

  const InfantFamilyInfo({
    this.stroller,
    this.lactationRoom,
    this.babySpareChair,
    this.infantsFamilyEtc,
  });

  factory InfantFamilyInfo.fromJson(Map<String, dynamic> json) {
    return InfantFamilyInfo(
      stroller: _emptyToNull(json['stroller']),
      lactationRoom: _emptyToNull(json['lactationroom']),
      babySpareChair: _emptyToNull(json['babysparechair']),
      infantsFamilyEtc: _emptyToNull(json['infantsfamilyetc']),
    );
  }

  Map<String, dynamic> toJson() => {
    'stroller': stroller,
    'lactationRoom': lactationRoom,
    'babySpareChair': babySpareChair,
    'infantsFamilyEtc': infantsFamilyEtc,
  };

  bool get isEmpty =>
      stroller == null &&
      lactationRoom == null &&
      babySpareChair == null &&
      infantsFamilyEtc == null;
}
