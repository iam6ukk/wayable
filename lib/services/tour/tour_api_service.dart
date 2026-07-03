import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wayable/utils/app_logger.dart';

/// 한국관광공사 무장애 여행 정보 OpenAPI 호출 서비스
/// 지금은 "호출이 되는지, 응답이 어떤 형태인지" 확인하는 용도.
class TourApiService {
  static const _baseUrl = 'apis.data.go.kr';
  static const _path = '/B551011/KorWithService2/areaBasedList2';

  /// 지역기반 관광정보 목록 조회
  /// areaCode: 지역코드 (서울=1)
  /// contentTypeId: 관광타입 (관광지=12)
  static Future<void> fetchAreaBasedList({
    required String areaCode,
    required String contentTypeId,
  }) async {
    final serviceKey = dotenv.env['TOUR_API_SERVICE_KEY'];

    if (serviceKey == null || serviceKey.isEmpty) {
      AppLogger.error('TOUR_API_SERVICE_KEY가 .env에 없습니다.');
      return;
    }

    // Uri.https가 쿼리 파라미터를 자동으로 인코딩해주므로,
    // .env에는 디코딩된(원본) 서비스키를 넣어야 함.
    final uri = Uri.https(_baseUrl, _path, {
      'serviceKey': serviceKey,
      'numOfRows': '10',
      'pageNo': '1',
      'MobileOS': 'ETC',
      'MobileApp': 'WayAble',
      '_type': 'json',
      'arrange': 'C',
      'contentTypeId': contentTypeId,
      'areaCode': areaCode,
    });

    AppLogger.debug('요청 URL: $uri');

    try {
      final response = await http.get(uri);

      AppLogger.debug('statusCode: ${response.statusCode}');

      if (response.statusCode != 200) {
        AppLogger.error('TourAPI 요청 실패 (HTTP ${response.statusCode})');
        return;
      }

      final decoded = jsonDecode(response.body);

      // 응답 구조 확인 (resultCode가 0000이 아니면 에러)
      final header = decoded['response']?['header'];
      AppLogger.info(
        'resultCode: ${header?['resultCode']}, resultMsg: ${header?['resultMsg']}',
      );

      final items = decoded['response']?['body']?['items']?['item'];

      if (items == null) {
        AppLogger.warning(
          '조회된 항목이 없습니다. (resultCode: ${header?['resultCode']})',
        );
        return;
      }

      // items가 1건이면 List가 아니라 단일 Map으로 올 수도 있으니 방어적으로 처리
      final List<dynamic> itemList = items is List ? items : [items];

      AppLogger.info('조회된 항목 수: ${itemList.length}');

      for (final item in itemList) {
        AppLogger.debug(
          'title: ${item['title']}, contentid: ${item['contentid']}, '
          'contenttypeid: ${item['contenttypeid']}, addr1: ${item['addr1']}, '
          'mapx/mapy: ${item['mapx']}, ${item['mapy']}',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('지역기반 관광정보 조회 중 예외 발생', error: e);
      AppLogger.debug('stackTrace: $stackTrace');
    }
  }
}
