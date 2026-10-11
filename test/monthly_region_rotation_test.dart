import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayable/model/region/area_code.dart';
import 'package:wayable/services/region/monthly_region_rotation.dart';

void main() {
  final areas =
      (jsonDecode(File('assets/data/area_codes.json').readAsStringSync())
              as List<dynamic>)
          .map((json) => AreaCode.fromJson(json as Map<String, dynamic>))
          .toList();

  test('2026년 봄부터 2027년 겨울까지 월별 기획 지역을 조회한다', () {
    const expectedCodes = [
      '11', '12', '26', // 2026년 봄: 서울, 전남광주, 부산
      '27', '28', '30', // 여름: 대구, 인천, 대전
      '31', '41', '43', // 가을: 울산, 경기, 충북
      '44', '47', '48', // 겨울: 충남, 경북, 경남
      '50', '51', '52', // 2027년 봄: 제주, 강원, 전북
      '36110', '11', '12', // 여름: 세종, 서울, 전남광주
      '26', '27', '28', // 가을: 부산, 대구, 인천
      '30', '31', '41', // 겨울: 대전, 울산, 경기
    ];

    for (var i = 0; i < expectedCodes.length; i++) {
      final date = DateTime(2026, 3 + i, 1);
      expect(
        pickMonthlyRegion(areas, date).code,
        expectedCodes[i],
        reason: '${date.year}년 ${date.month}월',
      );
    }
  });

  test('같은 달에는 날짜와 시각이 달라도 동일한 지역을 선택한다', () {
    expect(pickMonthlyRegion(areas, DateTime(2026, 10, 1)).code, '41');
    expect(pickMonthlyRegion(areas, DateTime(2026, 10, 31, 23, 59)).code, '41');
  });
}
