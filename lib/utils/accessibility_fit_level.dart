import '../model/accessibility/accessibility_field.dart';
import '../model/accessibility/accessibility_field_mapping.dart';
import '../model/accessibility/accessibility_profile.dart';
import '../model/user/user.dart';

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

/// 사용자가 선택한 접근성 상세 조건 대비 장소가 실제로 충족하는 비율로
/// 산정하는 적합 레벨. LV3 ⊂ LV2 ⊂ LV1 구조(레벨이 높을수록 조건이 엄격)라
/// 매칭률에 대응하는 최상위 레벨 하나만 갖는다.
///
/// 기준값(30/60/90%)은 초기 추정치이며, 서비스 운영 후 매칭률 분포를 보고
/// 조정될 수 있다.
enum AccessibilityFitLevel {
  lv1(0.30),
  lv2(0.60),
  lv3(0.90);

  const AccessibilityFitLevel(this.threshold);

  /// 이 레벨로 판정되기 위한 최소 매칭률.
  final double threshold;

  String get label => switch (this) {
    AccessibilityFitLevel.lv1 => '적합성 Lv.1',
    AccessibilityFitLevel.lv2 => '적합성 Lv.2',
    AccessibilityFitLevel.lv3 => '적합성 Lv.3',
  };
}

/// [calculateAccessibilityFit]의 결과.
///
/// 매칭률 하나만으로는 "선택한 조건이 없어 계산 자체가 불가능한 상태"(비회원,
/// 프로필 미설정, 필터에서 조건을 전부 끈 상태)와 "계산은 됐지만 LV1 기준에도
/// 못 미치는 상태"를 구분할 수 없어서, 화면에서 "레벨 산정중"과 배지 없음을
/// 다르게 보여줄 수 있도록 [isComputable]을 따로 둔다.
class AccessibilityFitResult {
  final bool isComputable;

  /// 0.0~1.0. isComputable이 false면 항상 0.
  final double matchRate;

  /// 매칭률이 LV1 기준에도 못 미치거나 계산 자체가 불가능하면 null.
  final AccessibilityFitLevel? level;

  const AccessibilityFitResult._({
    required this.isComputable,
    required this.matchRate,
    required this.level,
  });

  static const notComputable = AccessibilityFitResult._(
    isComputable: false,
    matchRate: 0,
    level: null,
  );
}

/// [selectedFields]는 여러 접근성 프로필에서 선택한 상세 필드를 하나로 합친
/// 목록이다. physicalAssist와 seniorCompanion처럼 프로필 간 겹치는 필드가
/// 있어도 Set이라 중복 없이 한 번만 분모에 들어간다.
///
/// [populatedFields]는 대상 장소가 실제 정보를 제공하는 필드
/// (TourSpot.populatedFields)다.
AccessibilityFitResult calculateAccessibilityFit({
  required Set<AccessibilityField> selectedFields,
  required Set<AccessibilityField> populatedFields,
}) {
  if (selectedFields.isEmpty) return AccessibilityFitResult.notComputable;

  final matchedCount = selectedFields.intersection(populatedFields).length;
  final matchRate = matchedCount / selectedFields.length;

  AccessibilityFitLevel? level;
  for (final candidate in AccessibilityFitLevel.values.reversed) {
    if (matchRate >= candidate.threshold) {
      level = candidate;
      break;
    }
  }

  return AccessibilityFitResult._(
    isComputable: true,
    matchRate: matchRate,
    level: level,
  );
}

/// 로그인한 회원이 "내 접근성 프로필 설정"에서 저장한 값을 [calculateAccessibilityFit]의
/// selectedFields 인자로 쓸 수 있게 펼친다. 프로필별 저장 필드가 빈 리스트면
/// (AppUser.accessibilityFieldsByProfile 컨벤션상 "전체 선택") 그 프로필의 전체
/// 필드로 치환한다.
///
/// 비회원(user == null)이거나 저장된 프로필이 하나도 없으면 빈 Set을 반환하고,
/// 그 경우 calculateAccessibilityFit은 AccessibilityFitResult.notComputable을
/// 돌려줘 "레벨 산정중" 표시로 이어진다.
Set<AccessibilityField> resolveSelectedFields(AppUser? user) {
  if (user == null) return const {};

  final selected = <AccessibilityField>{};
  for (final entry in user.accessibilityFieldsByProfile.entries) {
    final profile = _profileFromName(entry.key);
    if (profile == null) continue;

    if (entry.value.isEmpty) {
      selected.addAll(AccessibilityFieldMapping.mapping[profile] ?? const []);
    } else {
      selected.addAll(
        entry.value.map(_fieldFromName).whereType<AccessibilityField>(),
      );
    }
  }
  return selected;
}
