import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wayable/model/region/area_code.dart';

/// assets/data/area_codes.json(법정동 시/도·시군구 코드, 정적 참조 데이터)을 읽어온다.
/// 거의 안 바뀌는 데이터라 최초 로드 후 메모리에 캐싱한다.
class AreaCodeRepository {
  AreaCodeRepository._();

  static List<AreaCode>? _cache;

  static Future<List<AreaCode>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/data/area_codes.json');
    final decoded = json.decode(raw) as List<dynamic>;
    final areaCodes = decoded
        .map((e) => AreaCode.fromJson(e as Map<String, dynamic>))
        .toList();

    _cache = areaCodes;
    return areaCodes;
  }
}
