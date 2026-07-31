import '../accessibility/accessibility_field.dart';
import '../accessibility/accessibility_field_mapping.dart';
import '../accessibility/accessibility_profile.dart';

AccessibilityField? _fieldFromName(String name) {
  for (final field in AccessibilityField.values) {
    if (field.name == name) return field;
  }
  return null;
}

AccessibilityProfile? _profileFromName(String name) {
  for (final profile in AccessibilityProfile.values) {
    if (profile.name == name) return profile;
  }
  return null;
}

/// Firestore tourSpots/{contentId} 문서를 탐색 화면 카드에 필요한 형태로 매핑한 모델.
/// 문서 구조는 functions/src/model/index.ts의 FirestoreTourSpotDoc과 대응한다.
class TourSpot {
  final String contentId;
  final String title;
  final String addr1;
  final String? addr2;
  final String? firstImage;

  /// 상세화면에서 detailImage2로 추가 조회한 이미지(썸네일 제외, 최대 2장).
  /// firstImage와 합쳐서 저장목록 화면의 3장짜리 썸네일 줄에 그대로 쓰인다.
  final List<String> galleryImages;

  final String contentTypeId;

  /// 법정동 지역코드/시군구코드 (ldongCode2 체계). assets/data/area_codes.json의
  /// AreaCode.code / SigunguCode.code와 대응한다.
  final String? lDongRegnCd;
  final String? lDongSignguCd;

  /// 이 장소가 접근성 정보를 제공하는 대분류 목록.
  /// (Firestore accessibility.physical/visual/hearing/infantFamily 중
  /// 값이 하나라도 있는 그룹을 대응하는 AccessibilityProfile로 매핑)
  final Set<AccessibilityProfile> supportedProfiles;

  /// 실제 값이 채워진 개별 무장애정보 필드 (상세 필터 매칭용).
  final Set<AccessibilityField> populatedFields;

  const TourSpot({
    required this.contentId,
    required this.title,
    required this.addr1,
    this.addr2,
    this.firstImage,
    this.galleryImages = const [],
    this.contentTypeId = '',
    this.lDongRegnCd,
    this.lDongSignguCd,
    this.supportedProfiles = const {},
    this.populatedFields = const {},
  });

  factory TourSpot.fromFirestore(String id, Map<String, dynamic> data) {
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final accessibility = data['accessibility'] as Map<String, dynamic>?;

    final populatedFields = <AccessibilityField>{};
    for (final groupKey in ['physical', 'visual', 'hearing', 'infantFamily']) {
      final group = accessibility?[groupKey] as Map<String, dynamic>?;
      if (group == null) continue;
      group.forEach((key, value) {
        if (value == null || value.toString().isEmpty) return;
        final field = _fieldFromName(key);
        if (field != null) populatedFields.add(field);
      });
    }

    // seniorCompanion(고령자동반)은 Firestore에 별도 그룹이 없고 physical 그룹의
    // 일부 필드를 공유해서 쓰기 때문에, 그룹 존재 여부가 아니라 실제 채워진
    // 필드가 그 profile의 매핑에 하나라도 겹치는지로 판단해야 지체장애보조와
    // 고령자동반 아이콘이 둘 다 정확히 표시된다.
    final supportedProfiles = <AccessibilityProfile>{
      for (final entry in AccessibilityFieldMapping.mapping.entries)
        if (entry.value.any(populatedFields.contains)) entry.key,
    };

    return TourSpot(
      contentId: (basic['contentId'] ?? id).toString(),
      title: (basic['title'] as String?) ?? '',
      addr1: (basic['addr1'] as String?) ?? '',
      addr2: basic['addr2'] as String?,
      firstImage: basic['firstImage'] as String?,
      contentTypeId: (basic['contentTypeId'] as String?) ?? '',
      lDongRegnCd: basic['lDongRegnCd'] as String?,
      lDongSignguCd: basic['lDongSignguCd'] as String?,
      supportedProfiles: supportedProfiles,
      populatedFields: populatedFields,
    );
  }

  /// 저장목록(북마크) 문서 형태(users/{uid}/bookmarks/{folderId}/spots/{spotId})로
  /// 복제 저장할 때 쓰는 평평한 맵. tourSpots 원본 문서의 raw 필드가 아니라,
  /// 저장목록 카드 렌더링에 필요한 만큼만(이 클래스가 이미 정규화해둔 필드) 담는다.
  Map<String, dynamic> toBookmarkDoc() {
    return {
      'contentId': contentId,
      'title': title,
      'addr1': addr1,
      if (addr2 != null) 'addr2': addr2,
      if (firstImage != null) 'firstImage': firstImage,
      if (galleryImages.isNotEmpty) 'galleryImages': galleryImages,
      'contentTypeId': contentTypeId,
      if (lDongRegnCd != null) 'lDongRegnCd': lDongRegnCd,
      if (lDongSignguCd != null) 'lDongSignguCd': lDongSignguCd,
      'supportedProfiles': supportedProfiles.map((p) => p.name).toList(),
      'populatedFields': populatedFields.map((f) => f.name).toList(),
    };
  }

  factory TourSpot.fromBookmarkDoc(Map<String, dynamic> data) {
    final supportedProfiles = ((data['supportedProfiles'] as List?) ?? const [])
        .map((name) => _profileFromName(name as String))
        .whereType<AccessibilityProfile>()
        .toSet();
    final populatedFields = ((data['populatedFields'] as List?) ?? const [])
        .map((name) => _fieldFromName(name as String))
        .whereType<AccessibilityField>()
        .toSet();

    return TourSpot(
      contentId: data['contentId'] as String,
      title: (data['title'] as String?) ?? '',
      addr1: (data['addr1'] as String?) ?? '',
      addr2: data['addr2'] as String?,
      firstImage: data['firstImage'] as String?,
      galleryImages: ((data['galleryImages'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      contentTypeId: (data['contentTypeId'] as String?) ?? '',
      lDongRegnCd: data['lDongRegnCd'] as String?,
      lDongSignguCd: data['lDongSignguCd'] as String?,
      supportedProfiles: supportedProfiles,
      populatedFields: populatedFields,
    );
  }
}
