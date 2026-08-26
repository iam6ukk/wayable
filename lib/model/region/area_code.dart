/// TourAPI ldongCode2(법정동 코드 조회) 결과를 담는 시군구 코드.
///
/// TourAPI는 "수원시 장안구"처럼 구 단위까지 별도 항목으로 내려주지만, 2차 지역
/// 선택 화면에는 "수원시" 하나로만 보여준다. 대신 실제 여행지 데이터의
/// lDongSignguCd는 구 단위 코드로 찍혀 있을 수 있으므로, [memberCodes]에 그
/// 시/군이 소속한 모든 구 코드(자기 자신 포함)를 담아 매칭에 사용한다.
class SigunguCode {
  final String code;
  final String name;
  final List<String> memberCodes;

  const SigunguCode({required this.code, required this.name, required this.memberCodes});

  factory SigunguCode.fromJson(Map<String, dynamic> json) => SigunguCode(
    code: json['code'] as String,
    name: json['name'] as String,
    memberCodes: (json['memberCodes'] as List<dynamic>? ?? [json['code']])
        .map((e) => e as String)
        .toList(),
  );

  bool matches(String? spotSigunguCode) =>
      spotSigunguCode != null && memberCodes.contains(spotSigunguCode);

  // 관심 지역 선택(최대 3개)을 Set<SigunguCode>로 다루는 화면들이 code 값만
  // 같으면 같은 시/군구로 취급해야 한다 — 기본 식별 동등성(==)만으로는
  // AreaCodeRepository의 캐시된 객체가 아닌 다른 인스턴스가 섞였을 때
  // Set.contains/remove가 어긋난다.
  @override
  bool operator ==(Object other) => other is SigunguCode && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// TourAPI ldongCode2(법정동 코드 조회) 결과를 담는 시/도 코드.
/// assets/data/area_codes.json으로 앱에 번들되어 있다 (scripts/backfill/fetchAreaCodes.ts 참고).
class AreaCode {
  final String code;
  final String name;
  final List<SigunguCode> sigungu;

  const AreaCode({required this.code, required this.name, required this.sigungu});

  factory AreaCode.fromJson(Map<String, dynamic> json) => AreaCode(
    code: json['code'] as String,
    name: json['name'] as String,
    sigungu: _consolidateSigungu(json['sigungu'] as List<dynamic>),
  );

  /// "수원시 장안구", "수원시 권선구" 같은 구 단위 항목들을 "수원시" 하나로
  /// 묶는다. 구가 없는 시/군은 그대로 자기 코드 하나만 [SigunguCode.memberCodes]로 갖는다.
  static List<SigunguCode> _consolidateSigungu(List<dynamic> raw) {
    final entries = raw.map((e) => e as Map<String, dynamic>).toList();
    final byBaseName = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final baseName = (entry['name'] as String).split(' ').first;
      byBaseName.putIfAbsent(baseName, () => []).add(entry);
    }

    return byBaseName.entries.map((group) {
      final members = group.value;
      final parent = members.firstWhere(
        (m) => m['name'] == group.key,
        orElse: () => members.first,
      );
      return SigunguCode(
        code: parent['code'] as String,
        name: group.key,
        memberCodes: members.map((m) => m['code'] as String).toList(),
      );
    }).toList();
  }
}
