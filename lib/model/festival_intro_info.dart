/// detailIntro2 (소개정보 조회) 응답 중 contentTypeId=15 (행사/공연/축제) 전용 매핑 DTO
///
/// detailIntro2는 contentTypeId에 따라 응답 필드가 완전히 달라지는 API라서
/// (관광지용/문화시설용/축제용/레포츠용/숙박용/쇼핑용/음식점용 필드가 한 테이블에
/// 다 섞여 있음), 실제로는 요청 시점에 contentTypeId=15로 보냈을 때만 유효한
/// 필드들만 뽑아서 별도 DTO로 분리했습니다.
///
/// 홈 화면 "이번달 행사·축제 배너"에서 이 DTO를 사용하게 됩니다.
class FestivalIntroInfo {
  final String contentId;
  final String contentTypeId; // 항상 "15"

  final String? ageLimit; // 관람 가능연령
  final String? bookingPlace; // 예매처
  final String? discountInfo; // 할인정보
  final String? eventEndDate; // 행사 종료일 (YYYYMMDD)
  final String? eventHomepage; // 행사 홈페이지
  final String? eventPlace; // 행사 장소
  final String? eventStartDate; // 행사 시작일 (YYYYMMDD)
  final String? festivalGrade; // 축제 등급
  final String? festivalType; // 축제 종류
  final String? placeInfo; // 행사장 위치안내
  final String? playTime; // 공연시간
  final String? program; // 행사 프로그램
  final String? progressType; // 행사 진행 상황
  final String? spendTime; // 관람 소요시간
  final String? sponsor1; // 주최자 정보
  final String? sponsor1Tel; // 주최자 연락처
  final String? sponsor2; // 주관사 정보
  final String? sponsor2Tel; // 주관사 연락처
  final String? subEvent; // 부대행사
  final String? useTimeFestival; // 이용요금

  const FestivalIntroInfo({
    required this.contentId,
    this.contentTypeId = '15',
    this.ageLimit,
    this.bookingPlace,
    this.discountInfo,
    this.eventEndDate,
    this.eventHomepage,
    this.eventPlace,
    this.eventStartDate,
    this.festivalGrade,
    this.festivalType,
    this.placeInfo,
    this.playTime,
    this.program,
    this.progressType,
    this.spendTime,
    this.sponsor1,
    this.sponsor1Tel,
    this.sponsor2,
    this.sponsor2Tel,
    this.subEvent,
    this.useTimeFestival,
  });

  factory FestivalIntroInfo.fromJson(Map<String, dynamic> json) {
    String? emptyToNull(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return FestivalIntroInfo(
      contentId: json['contentid'].toString(),
      contentTypeId: json['contenttypeid']?.toString() ?? '15',
      ageLimit: emptyToNull(json['agelimit']),
      bookingPlace: emptyToNull(json['bookingplace']),
      discountInfo: emptyToNull(json['discountinfofestival']),
      eventEndDate: emptyToNull(json['eventenddate']),
      eventHomepage: emptyToNull(json['eventhomepage']),
      eventPlace: emptyToNull(json['eventplace']),
      eventStartDate: emptyToNull(json['eventstartdate']),
      festivalGrade: emptyToNull(json['festivalgrade']),
      festivalType: emptyToNull(json['festivaltype']),
      placeInfo: emptyToNull(json['placeinfo']),
      playTime: emptyToNull(json['playtime']),
      program: emptyToNull(json['program']),
      progressType: emptyToNull(json['progresstype']),
      spendTime: emptyToNull(json['spendtimefestival']),
      sponsor1: emptyToNull(json['sponsor1']),
      sponsor1Tel: emptyToNull(json['sponsor1tel']),
      sponsor2: emptyToNull(json['sponsor2']),
      sponsor2Tel: emptyToNull(json['sponsor2tel']),
      subEvent: emptyToNull(json['subevent']),
      useTimeFestival: emptyToNull(json['usetimefestival']),
    );
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'contentTypeId': contentTypeId,
    'ageLimit': ageLimit,
    'bookingPlace': bookingPlace,
    'discountInfo': discountInfo,
    'eventEndDate': eventEndDate,
    'eventHomepage': eventHomepage,
    'eventPlace': eventPlace,
    'eventStartDate': eventStartDate,
    'festivalGrade': festivalGrade,
    'festivalType': festivalType,
    'placeInfo': placeInfo,
    'playTime': playTime,
    'program': program,
    'progressType': progressType,
    'spendTime': spendTime,
    'sponsor1': sponsor1,
    'sponsor1Tel': sponsor1Tel,
    'sponsor2': sponsor2,
    'sponsor2Tel': sponsor2Tel,
    'subEvent': subEvent,
    'useTimeFestival': useTimeFestival,
  };

  /// "이번달 행사인지" 판단용 헬퍼.
  /// eventStartDate/eventEndDate가 YYYYMMDD 문자열이라 파싱해서 비교.
  bool isOngoingOn(DateTime date) {
    final start = _parseYyyymmdd(eventStartDate);
    final end = _parseYyyymmdd(eventEndDate);
    if (start == null) return false;
    final endDate = end ?? start;
    return !date.isBefore(start) && !date.isAfter(endDate);
  }

  static DateTime? _parseYyyymmdd(String? s) {
    if (s == null || s.length != 8) return null;
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(4, 6));
    final d = int.tryParse(s.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
