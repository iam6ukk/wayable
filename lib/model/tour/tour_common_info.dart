/// detailCommon2 (공통정보 조회) 응답 매핑 DTO.
///
/// 상세 화면 상단(제목/주소/이미지/전화번호/홈페이지)에 필요한 필드만 담는다.
/// contentTypeId와 무관하게 항상 동일한 필드 구조로 내려오는 공통 API라
/// FestivalIntroInfo/TourIntroInfo처럼 타입별로 나눌 필요가 없다.
class TourCommonInfo {
  final String contentId;
  final String contentTypeId;
  final String title;
  final String addr1;
  final String? addr2;
  final String? tel;
  final String? homepage;
  final String? overview;
  final String? firstImage;
  final String? firstImage2;

  /// detailCommon2 원본 응답 전체 (필드별 실제 데이터 확인용 임시 디버그 뷰에서 사용).
  final Map<String, dynamic> raw;

  const TourCommonInfo({
    required this.contentId,
    required this.contentTypeId,
    required this.title,
    required this.addr1,
    this.addr2,
    this.tel,
    this.homepage,
    this.overview,
    this.firstImage,
    this.firstImage2,
    this.raw = const {},
  });

  factory TourCommonInfo.fromJson(Map<String, dynamic> json) {
    String? emptyToNull(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return TourCommonInfo(
      contentId: json['contentid'].toString(),
      contentTypeId: json['contenttypeid']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      addr1: (json['addr1'] as String?) ?? '',
      addr2: emptyToNull(json['addr2']),
      tel: emptyToNull(json['tel']),
      homepage: _extractHomepageUrl(json['homepage'] as String?),
      overview: emptyToNull(json['overview']),
      firstImage: emptyToNull(json['firstimage']),
      firstImage2: emptyToNull(json['firstimage2']),
      raw: json,
    );
  }

  /// homepage 필드는 `<a href="https://...">사이트명</a>` 형태의 HTML 문자열로
  /// 내려오는 경우가 많아, 링크 텍스트로 보여줄 순수 URL만 뽑아낸다.
  static String? _extractHomepageUrl(String? html) {
    if (html == null || html.isEmpty) return null;
    final match = RegExp(r'href="([^"]+)"').firstMatch(html);
    return match?.group(1) ?? html;
  }
}
