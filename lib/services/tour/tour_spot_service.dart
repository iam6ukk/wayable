import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:wayable/model/tour/tour_spot.dart';
import 'package:wayable/utils/app_logger.dart';

/// [TourSpotService.search]가 반환하는 한 페이지 결과.
class TourSpotSearchResult {
  final List<TourSpot> spots;
  final int totalCount;

  const TourSpotSearchResult({required this.spots, required this.totalCount});

  static const empty = TourSpotSearchResult(spots: [], totalCount: 0);
}

/// Firestore tourSpots 컬렉션 조회 서비스 (맞춤 여행지 탐색 화면용).
class TourSpotService {
  final _collection = FirebaseFirestore.instance.collection('tourSpots');
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  /// 검색어(title) 부분일치·접근성 상세필드(OR)·지역/카테고리 필터를 전부
  /// Cloud Function(searchTourSpots)에서 처리하고, 요청한 페이지 결과만 받아온다.
  ///
  /// 예전에는 이 필터링을 클라이언트에서 직접 했는데, 완전성(빠짐없이 찾기)을
  /// 보장하려면 컬렉션 전체를 클라이언트가 받아야 해서 실기기가 파싱 도중
  /// 멎는 문제가 있었다. 서버(Cloud Function)는 메모리가 넉넉하고 Firestore와
  /// 같은 리전에서 내부망으로 붙기 때문에, 전체를 훑어 거른 뒤 이미 필터링된
  /// 페이지 하나(items)와 전체 건수(totalCount)만 클라이언트로 돌려준다.
  Future<TourSpotSearchResult> search({
    String? keyword,
    String? regionCode,
    List<String>? categoryIds,
    List<String>? acceptableFields,
    List<String>? sigunguMemberCodes,
    int page = 1,
    int pageSize = 6,
  }) async {
    try {
      final result = await _functions.httpsCallable('searchTourSpots').call<
          Object?>({
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (regionCode != null) 'regionCode': regionCode,
        if (categoryIds != null && categoryIds.isNotEmpty)
          'categoryIds': categoryIds,
        if (acceptableFields != null && acceptableFields.isNotEmpty)
          'acceptableFields': acceptableFields,
        if (sigunguMemberCodes != null && sigunguMemberCodes.isNotEmpty)
          'sigunguMemberCodes': sigunguMemberCodes,
        'page': page,
        'pageSize': pageSize,
      });

      final data = _asStringKeyedMap(result.data);
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((item) {
            final itemMap = _asStringKeyedMap(item);
            return TourSpot.fromFirestore(
              itemMap['id']?.toString() ?? '',
              itemMap,
            );
          })
          .toList();
      final totalCount = (data['totalCount'] as num?)?.toInt() ?? items.length;

      return TourSpotSearchResult(spots: items, totalCount: totalCount);
    } catch (e) {
      AppLogger.error('[TourSpotService] tourSpots 검색 실패', error: e);
      return TourSpotSearchResult.empty;
    }
  }

  /// 홈 화면 "발견 여행지" 배너용 후보군. 랜덤으로 하나 골라 보여주는 용도라
  /// 검색처럼 빠짐없이 다 훑을 필요가 없어서, Cloud Function 없이 가볍게
  /// 일부만 직접 가져온다.
  Future<List<TourSpot>> fetchDiscoveryCandidates({int limit = 200}) async {
    try {
      final snapshot = await _collection.limit(limit).get();
      return snapshot.docs
          .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('[TourSpotService] 발견 여행지 후보 조회 실패', error: e);
      return [];
    }
  }

  /// 홈 화면 "가장 많이 저장된 여행지" 캐러셀용. 컬렉션 전체를 bookmarkCount
  /// 내림차순으로 가져온 뒤(정렬은 Firestore가 서버에서 처리) 호출부에서 상위
  /// 몇 개만 뽑아 쓴다.
  Future<List<TourSpot>> fetchMostBookmarked() async {
    try {
      final snapshot = await _collection
          .orderBy('bookmarkCount', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('[TourSpotService] 최다 저장 여행지 조회 실패', error: e);
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

/// Cloud Functions 콜러블 응답은 `Map<Object?, Object?>`로 내려오는 경우가 있어,
/// TourSpot.fromFirestore가 기대하는 `Map<String, dynamic>`으로 재귀적으로 맞춘다.
Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), _normalize(v)));
  }
  return const {};
}

dynamic _normalize(dynamic value) {
  if (value is Map) return _asStringKeyedMap(value);
  if (value is List) return value.map(_normalize).toList();
  return value;
}
