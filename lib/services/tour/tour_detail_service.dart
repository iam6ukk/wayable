import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wayable/model/tour/tour_accessibility_info.dart';
import 'package:wayable/model/tour/tour_common_info.dart';
import 'package:wayable/model/tour/tour_intro_info.dart';
import 'package:wayable/utils/app_logger.dart';

/// 여행지 상세 화면용 한국관광공사 무장애 여행 정보 OpenAPI 조회 서비스.
/// contentId 기준으로 공통정보(detailCommon2)/소개정보(detailIntro2)/
/// 무장애정보(detailWithTour2)를 각각 조회한다.
class TourDetailService {
  static const _baseUrl = 'apis.data.go.kr';
  static const _basePath = '/B551011/KorWithService2';

  Future<Map<String, dynamic>?> _fetchFirstItem(
    String operation,
    Map<String, String> params,
  ) async {
    final serviceKey = dotenv.env['TOUR_API_SERVICE_KEY'];
    if (serviceKey == null || serviceKey.isEmpty) {
      AppLogger.error('TOUR_API_SERVICE_KEY가 .env에 없습니다.');
      return null;
    }

    final uri = Uri.https(_baseUrl, '$_basePath/$operation', {
      'serviceKey': serviceKey,
      'MobileOS': 'ETC',
      'MobileApp': 'WayAble',
      '_type': 'json',
      'numOfRows': '1',
      'pageNo': '1',
      ...params,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        AppLogger.error('$operation 요청 실패 (HTTP ${response.statusCode})');
        return null;
      }

      final decoded = jsonDecode(response.body);
      final header = decoded['response']?['header'];
      final resultCode = header?['resultCode'];
      // "03"은 NODATA_ERROR로 "결과 없음"을 뜻하는 정상 응답이라 에러로 취급하지 않는다.
      if (resultCode != '0000' && resultCode != '03') {
        AppLogger.error('$operation 에러 [$resultCode] ${header?['resultMsg']}');
      }

      final items = decoded['response']?['body']?['items'];
      // 결과가 없으면 items가 빈 문자열("")로 내려오는 경우가 있다.
      if (items == null || items is! Map) return null;

      final item = items['item'];
      if (item == null || item is! Map && item is! List) return null;
      if (item is List && item.isEmpty) return null;

      final itemMap = item is List ? item.first : item;
      return Map<String, dynamic>.from(itemMap as Map);
    } catch (e, stackTrace) {
      AppLogger.error('$operation 조회 중 예외 발생', error: e);
      AppLogger.debug('stackTrace: $stackTrace');
      return null;
    }
  }

  /// 공통정보 조회 (제목/주소/이미지/전화번호/홈페이지/개요).
  /// 무장애 여행정보 전용 API(KorWithService2)는 일반 KorService2의 detailCommon2와
  /// 달리 defaultYN/firstImageYN/addrinfoYN 등 부가 파라미터를 지원하지 않고
  /// INVALID_REQUEST_PARAMETER_ERROR로 응답하므로 contentId만 넘긴다.
  Future<TourCommonInfo?> fetchCommonInfo(String contentId) async {
    final json = await _fetchFirstItem('detailCommon2', {
      'contentId': contentId,
    });
    if (json == null) return null;
    return TourCommonInfo.fromJson(json);
  }

  /// 소개정보 조회 ("시설정보"로 보여줄 운영시간/휴무일/입장료 등).
  Future<TourIntroInfo?> fetchIntroInfo(
    String contentId,
    String contentTypeId,
  ) async {
    final json = await _fetchFirstItem('detailIntro2', {
      'contentId': contentId,
      'contentTypeId': contentTypeId,
    });
    if (json == null) return null;
    return TourIntroInfo.fromJson(contentId, contentTypeId, json);
  }

  /// 무장애여행 정보 조회 ("편의정보" 탭에 보여줄 장애 유형별 편의시설).
  Future<TourAccessibilityInfo?> fetchAccessibilityInfo(
    String contentId,
  ) async {
    final json = await _fetchFirstItem('detailWithTour2', {
      'contentId': contentId,
    });
    if (json == null) return null;
    return TourAccessibilityInfo.fromJson(json);
  }
}
