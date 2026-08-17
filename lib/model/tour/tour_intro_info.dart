/// detailIntro2 (소개정보 조회) 응답 DTO.
///
/// TourAPI detailIntro2는 contentTypeId(관광지/문화시설/축제/레포츠/숙박/쇼핑/음식점)별로
/// 응답 필드명이 전부 다르게 내려온다(예: 운영시간이 관광지는 usetime, 문화시설은
/// usetimeculture, 레포츠는 usetimeleports). 어떤 필드를 시설정보로 보여줄지는
/// contentTypeId별로 [kFacilityFieldsByContentType]에서 정의하고, 이 DTO는 원본
/// 응답을 그대로 보관해 화면에서 필요한 필드만 골라 쓰게 한다.
class TourIntroInfo {
  final String contentId;
  final String contentTypeId;

  /// detailIntro2 원본 응답 전체.
  final Map<String, dynamic> raw;

  const TourIntroInfo({
    required this.contentId,
    required this.contentTypeId,
    this.raw = const {},
  });

  factory TourIntroInfo.fromJson(
    String contentId,
    String contentTypeId,
    Map<String, dynamic> json,
  ) {
    return TourIntroInfo(
      contentId: contentId,
      contentTypeId: contentTypeId,
      raw: json,
    );
  }
}
