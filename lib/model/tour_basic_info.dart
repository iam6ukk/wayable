/// areaBasedSyncList2 (무장애 여행정보 동기화 목록 조회) 응답 매핑 DTO
///
/// 목록/카드 화면(내 주변, 행사 배너 등)에 필요한 최소 정보만 담습니다.
/// TourAPI 원본 필드명을 그대로 유지 (문서 대조 편의를 위해).
///
/// Java 비유: 목록 조회용 Response DTO. 상세정보(접근성 등)는
/// 별도 DTO(TourAccessibilityInfo)로 분리되어 있으니, 이 클래스에는
/// "리스트에 뿌릴 카드"에 필요한 필드만 둡니다.
class TourBasicInfo {
  final String contentId;
  final String contentTypeId; // 12,14,15,28,32,38,39
  final String title;
  final String addr1;
  final String? addr2;

  final String? areaCode;
  final String? sigunguCode;

  final String? cat1;
  final String? cat2;
  final String? cat3;

  final double? mapX; // 경도
  final double? mapY; // 위도

  final String? firstImage;
  final String? firstImage2;
  final String? cpyrhtDivCd; // Type1: 출처표시 권장 / Type3: 변경금지

  // 법정동 (4.3 신규 필드)
  final String? lDongRegnCd;
  final String? lDongSignguCd;

  // 분류체계 (4.3 신규 필드)
  final String? lclsSystm1;
  final String? lclsSystm2;
  final String? lclsSystm3;

  final String createdTime; // YYYYMMDDHHmmss
  final String modifiedTime; // YYYYMMDDHHmmss

  /// 1=표출, 0=비표출. 배치에서 0이면 캐시에서 삭제 처리.
  final int showFlag;

  final String? tel;
  final String? zipcode;

  const TourBasicInfo({
    required this.contentId,
    required this.contentTypeId,
    required this.title,
    required this.addr1,
    this.addr2,
    this.areaCode,
    this.sigunguCode,
    this.cat1,
    this.cat2,
    this.cat3,
    this.mapX,
    this.mapY,
    this.firstImage,
    this.firstImage2,
    this.cpyrhtDivCd,
    this.lDongRegnCd,
    this.lDongSignguCd,
    this.lclsSystm1,
    this.lclsSystm2,
    this.lclsSystm3,
    required this.createdTime,
    required this.modifiedTime,
    required this.showFlag,
    this.tel,
    this.zipcode,
  });

  factory TourBasicInfo.fromJson(Map<String, dynamic> json) {
    // TourAPI는 빈 값이면 "" 로 오는 경우가 많아서, 빈 문자열은 null로 정규화.
    String? emptyToNull(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    double? toDouble(dynamic v) {
      final s = emptyToNull(v);
      if (s == null) return null;
      return double.tryParse(s);
    }

    return TourBasicInfo(
      contentId: json['contentid'].toString(),
      contentTypeId: json['contenttypeid'].toString(),
      title: json['title'] as String,
      addr1: (json['addr1'] as String?) ?? '',
      addr2: emptyToNull(json['addr2']),
      areaCode: emptyToNull(json['areacode']),
      sigunguCode: emptyToNull(json['sigungucode']),
      cat1: emptyToNull(json['cat1']),
      cat2: emptyToNull(json['cat2']),
      cat3: emptyToNull(json['cat3']),
      mapX: toDouble(json['mapx']),
      mapY: toDouble(json['mapy']),
      firstImage: emptyToNull(json['firstimage']),
      firstImage2: emptyToNull(json['firstimage2']),
      cpyrhtDivCd: emptyToNull(json['cpyrhtDivCd']),
      lDongRegnCd: emptyToNull(json['lDongRegnCd']),
      lDongSignguCd: emptyToNull(json['lDongSignguCd']),
      lclsSystm1: emptyToNull(json['lclsSystm1']),
      lclsSystm2: emptyToNull(json['lclsSystm2']),
      lclsSystm3: emptyToNull(json['lclsSystm3']),
      createdTime: json['createdtime'].toString(),
      modifiedTime: json['modifiedtime'].toString(),
      showFlag: int.parse(json['showflag'].toString()),
      tel: emptyToNull(json['tel']),
      zipcode: emptyToNull(json['zipcode']),
    );
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'contentTypeId': contentTypeId,
    'title': title,
    'addr1': addr1,
    'addr2': addr2,
    'areaCode': areaCode,
    'sigunguCode': sigunguCode,
    'cat1': cat1,
    'cat2': cat2,
    'cat3': cat3,
    'mapX': mapX,
    'mapY': mapY,
    'firstImage': firstImage,
    'firstImage2': firstImage2,
    'cpyrhtDivCd': cpyrhtDivCd,
    'lDongRegnCd': lDongRegnCd,
    'lDongSignguCd': lDongSignguCd,
    'lclsSystm1': lclsSystm1,
    'lclsSystm2': lclsSystm2,
    'lclsSystm3': lclsSystm3,
    'createdTime': createdTime,
    'modifiedTime': modifiedTime,
    'showFlag': showFlag,
    'tel': tel,
    'zipcode': zipcode,
  };
}
