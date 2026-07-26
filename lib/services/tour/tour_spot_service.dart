import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wayable/model/tour/tour_spot.dart';
import 'package:wayable/utils/app_logger.dart';

/// Firestore tourSpots 컬렉션 조회 서비스 (맞춤 여행지 탐색 화면용).
class TourSpotService {
  // 지역/카테고리/상세필드 필터가 전부 클라이언트 사이드에서 걸러지기 때문에
  // (explore_screen.dart의 _matchesFilters — Firestore 복합 색인이 아직 없어서
  // 서버 쿼리에 조건을 못 태움), 필터링 여지를 남기려고 넉넉하게 가져온다.
  static const _defaultLimit = 200;

  final _collection = FirebaseFirestore.instance.collection('tourSpots');

  /// 최대 [limit]건을 가져온다. title 검색어 등 나머지 필터는 explore_screen.dart의
  /// _matchesFilters에서 클라이언트 사이드로 처리한다 (Firestore 접두어 일치 쿼리로는
  /// "대전선사박물관"을 "박물관"으로 찾는 부분 일치 검색이 불가능해서).
  Future<List<TourSpot>> search({int limit = _defaultLimit}) async {
    try {
      final snapshot = await _collection.limit(limit).get();
      return snapshot.docs
          .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('[TourSpotService] tourSpots 조회 실패', error: e);
      return [];
    }
  }

  /// [regionCode](TourSpot.lDongRegnCd, 시/도 코드)에 속하는 여행지를 콘텐츠
  /// 타입 구분 없이 전부 서버 쿼리로 가져온다 (홈 화면 "이번 달 추천 도시" 배너용).
  Future<List<TourSpot>> searchByRegion(String regionCode) async {
    try {
      final snapshot = await _collection
          .where('basic.lDongRegnCd', isEqualTo: regionCode)
          .get();
      return snapshot.docs
          .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('[TourSpotService] 지역별 여행지 조회 실패', error: e);
      return [];
    }
  }
}
