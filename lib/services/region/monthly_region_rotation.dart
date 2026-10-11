import 'package:wayable/model/region/area_code.dart';

/// 2026년 3월 서울을 시작으로 목록 순서대로 매달 추천 지역을 순환한다.
/// [date]는 한국 시간 기준 날짜를 전달한다.
AreaCode pickMonthlyRegion(List<AreaCode> areaCodes, DateTime date) {
  final monthDiff = (date.year - 2026) * 12 + date.month - 3;
  return areaCodes[monthDiff % areaCodes.length];
}
