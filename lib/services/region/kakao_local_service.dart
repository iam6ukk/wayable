import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wayable/utils/app_logger.dart';

/// [KakaoLocalService.reverseGeocodeDistrict]의 결과.
/// sigungu 이름만으로는 전국에 "중구"/"동구"/"서구"처럼 같은 이름이
/// 여러 시/도에 걸쳐 있어서 구별이 안 되므로, sido까지 같이 들고 다닌다.
class KakaoRegion {
  const KakaoRegion({required this.sido, required this.sigungu});

  /// region_1depth_name (예: "서울특별시", "경기도").
  final String sido;

  /// region_2depth_name (예: "동래구", "수원시 장안구").
  final String sigungu;
}

/// Kakao Local API(좌표 → 행정구역 코드)로 GPS 좌표를 시/도+시군구 이름으로 바꾼
/// 카카오 로그인용 KAKAO_NATIVE_APP_KEY와는 별개로 Kakao Developers 콘솔에서
/// 발급받는 REST API 키가 .env의 KAKAO_REST_API_KEY로 필요하다.
class KakaoLocalService {
  static const _endpoint =
      'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json';

  /// 실패 시 null. 이 앱의 2차 지역(SigunguCode)과 맞추는 건 호출부(home_screen.dart)에서 처리한다.
  Future<KakaoRegion?> reverseGeocodeDistrict({
    required double latitude,
    required double longitude,
  }) async {
    final restApiKey = dotenv.env['KAKAO_REST_API_KEY'];
    if (restApiKey == null || restApiKey.isEmpty) {
      AppLogger.warning('[KakaoLocal] KAKAO_REST_API_KEY 미설정');
      return null;
    }

    try {
      final uri = Uri.parse(_endpoint).replace(
        queryParameters: {
          'x': longitude.toString(),
          'y': latitude.toString(),
          'input_coord': 'WGS84',
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK $restApiKey'},
      );

      if (response.statusCode != 200) {
        AppLogger.warning(
          '[KakaoLocal] coord2regioncode 실패: ${response.statusCode} '
          '(x=$longitude, y=$latitude) body=${response.body}',
        );
        return null;
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final documents = (body['documents'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (documents.isEmpty) return null;

      // region_type "B"(법정동) 문서가 TourSpot.addr1의 행정구역 표기와 대응한다.
      final beopjeongdong = documents.firstWhere(
        (doc) => doc['region_type'] == 'B',
        orElse: () => documents.first,
      );

      final sido = beopjeongdong['region_1depth_name'] as String?;
      final sigungu = beopjeongdong['region_2depth_name'] as String?;
      if (sido == null || sido.isEmpty || sigungu == null || sigungu.isEmpty) {
        return null;
      }
      return KakaoRegion(sido: sido, sigungu: sigungu);
    } catch (e) {
      AppLogger.error('[KakaoLocal] 역지오코딩 실패', error: e);
      return null;
    }
  }
}
