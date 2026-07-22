/// detailIntro2 (소개정보 조회) 응답을 "시설정보" 화면 표시용으로 정규화한 DTO.
///
/// TourAPI detailIntro2는 contentTypeId(관광지/문화시설/축제/레포츠/숙박/쇼핑/음식점)별로
/// 응답 필드명이 전부 다르게 내려온다(예: 운영시간이 관광지는 usetime, 문화시설은
/// usetimeculture, 레포츠는 usetimeleports). 한 번의 호출에는 요청한 contentTypeId에
/// 해당하는 필드만 채워져 오기 때문에, 알려진 후보 필드명을 전부 순서대로 시도해서
/// 값이 있는 것만 뽑아내는 방식으로 타입별 분기 없이 하나의 DTO로 정규화한다.
class TourIntroInfo {
  final String contentId;
  final String contentTypeId;
  final String? operatingHours; // 운영시간
  final String? restDate; // 휴무일
  final String? useFee; // 입장료/이용요금
  final String? infoCenter; // 문의처 전화번호 (공통정보 tel이 없을 때 보조로 사용)

  /// detailIntro2 원본 응답 전체 (필드별 실제 데이터 확인용 임시 디버그 뷰에서 사용).
  final Map<String, dynamic> raw;

  const TourIntroInfo({
    required this.contentId,
    required this.contentTypeId,
    this.operatingHours,
    this.restDate,
    this.useFee,
    this.infoCenter,
    this.raw = const {},
  });

  static const _operatingHoursKeys = [
    'usetime',
    'usetimeculture',
    'usetimeleports',
    'usetimefestival',
    'opentime',
    'opentimefood',
    'checkintime',
  ];

  static const _restDateKeys = [
    'restdate',
    'restdateculture',
    'restdateleports',
    'restdateshopping',
    'restdatefood',
    'restdatelodging',
  ];

  static const _useFeeKeys = ['usefee', 'usefeeleports'];

  static const _infoCenterKeys = [
    'infocenter',
    'infocenterculture',
    'infocenterleports',
    'infocenterlodging',
    'infocentershopping',
    'infocenterfood',
    'infocentertourcourse',
  ];

  factory TourIntroInfo.fromJson(
    String contentId,
    String contentTypeId,
    Map<String, dynamic> json,
  ) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final v = json[key];
        if (v == null) continue;
        final s = v.toString();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    return TourIntroInfo(
      contentId: contentId,
      contentTypeId: contentTypeId,
      operatingHours: pick(_operatingHoursKeys),
      restDate: pick(_restDateKeys),
      useFee: pick(_useFeeKeys),
      infoCenter: pick(_infoCenterKeys),
      raw: json,
    );
  }
}
