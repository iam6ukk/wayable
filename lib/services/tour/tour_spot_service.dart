import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
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
      final result = await _functions
          .httpsCallable('searchTourSpots')
          .call<Object?>({
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
      final items = (data['items'] as List<dynamic>? ?? const []).map((item) {
        final itemMap = _asStringKeyedMap(item);
        return TourSpot.fromFirestore(itemMap['id']?.toString() ?? '', itemMap);
      }).toList();
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

  /// 홈 화면 "발견 여행지" 초기 로드/새로고침용 반경 검색. `basic.mapY`(위도)
  /// 범위로 Firestore에서 1차로 걸러 후보군을 가져온 뒤, 그 안에서 실제
  /// 좌표 거리(위도+경도 모두 사용)로 [radiusKm] 원 안에 드는지 다시 정밀
  /// 필터링한다. 위도 범위만으로는 같은 위도라도 경도가 먼 지점이 섞여
  /// 들어오기 때문에 클라이언트 정밀 필터가 필수다. 랜덤 선택은 호출부
  /// (home_screen.dart)의 책임이라 여기서는 후보 리스트만 반환한다.
  ///
  /// [limit]은 정렬 없이 그냥 상한만 거는 것이라 "가장 가까운 N개" 보장은
  /// 없다 — 호출부가 이 안에서 무작위로 하나를 뽑는 용도(추천)라 어차피
  /// 순서가 중요하지 않아서 괜찮다. "정확히 가장 가까운 N개"가 필요한
  /// 곳(지도 화면 등)에는 이 파라미터를 그대로 쓰면 안 된다.
  ///
  /// Firestore는 range 필터(`isGreaterThan`/`isLessThan`)를 쓰면 orderBy를
  /// 안 줘도 그 필드(mapY) 기준 오름차순으로 암묵 정렬한다. 그 상태로
  /// limit만 걸면 매번 반경의 남쪽 끝 [limit]건만 고정으로 받아오게 되어
  /// (풀이 [limit]건보다 크면 북쪽 절반은 후보에 아예 못 들어옴), 결과가
  /// 매번 특정 방향으로 쏠린다. Firestore가 "완전 무작위 N건" 쿼리 자체를
  /// 지원하지 않아 진짜 균등 샘플링은 안 되지만, 호출마다 오름차순/
  /// 내림차순을 무작위로 바꿔 남쪽/북쪽 끝을 번갈아 받아오는 것만으로도
  /// "항상 같은 쪽으로 고정" 문제는 없앨 수 있다.
  Future<List<TourSpot>> searchNearby({
    required double centerLat,
    required double centerLng,
    double radiusKm = 100,
    String? excludeSpotId,
    int limit = 200,
  }) async {
    try {
      // 위도 1도 ≈ 111km.
      final latDelta = radiusKm / 111.0;
      final snapshot = await _collection
          .where('basic.mapY', isGreaterThan: centerLat - latDelta)
          .where('basic.mapY', isLessThan: centerLat + latDelta)
          .orderBy('basic.mapY', descending: Random().nextBool())
          .limit(limit)
          .get();

      final radiusMeters = radiusKm * 1000;
      return snapshot.docs
          .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
          .where((spot) {
            if (spot.contentId == excludeSpotId) return false;
            if (spot.mapX == null || spot.mapY == null) return false;
            final distanceMeters = Geolocator.distanceBetween(
              centerLat,
              centerLng,
              spot.mapY!,
              spot.mapX!,
            );
            return distanceMeters <= radiusMeters;
          })
          .toList();
    } catch (e) {
      AppLogger.error('[TourSpotService] 주변 여행지 반경 조회 실패', error: e);
      return [];
    }
  }

  /// bookmarkCount를 확인하고 있다가 실시간으로 변경될 수 있도록 스냅샷 리스너를 쓴다.
  /// 상위 3개만 표출하므로 서버 쿼리 단계에서 limit(3)으로 잘라 받아온다.
  Stream<List<TourSpot>> watchMostBookmarked() {
    return _collection
        .orderBy('bookmarkCount', descending: true)
        .limit(3)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TourSpot.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// [regionCode](TourSpot.lDongRegnCd, 시/도 코드)에 속하는 여행지를 콘텐츠
  /// 타입 구분 없이 전부 서버 쿼리로 가져온다 (홈 화면 "이번 달 추천 도시" 배너용).
  // 카테고리 없이 키워드만으로 찾는 검색은 부분일치라 서버 쿼리로 표현할 수
  // 없어 지역 전체를 그대로 받아야 한다. 실측 최대치(2026-08 기준 경기도
  // 약 1,637건)를 기준으로 여유 있게 잡은 안전 상한이라, 데이터가 계속
  // 늘어나므로 주기적으로 실측 최대치를 다시 확인해 조정해야 한다.
  static const _regionFetchSafetyLimit = 600;

  /// [contentTypeId]가 있으면 지역+카테고리를 서버에서 같이 좁혀서 받는다
  /// (카테고리로 좁혀도 실측상 지역당 최대 수백 건 수준이라 별도 상한이
  /// 필요 없다). 카테고리 없이 부르면(키워드만으로 클라이언트 필터링할
  /// 때) [_regionFetchSafetyLimit] 상한을 건다.
  Future<List<TourSpot>> searchByRegion(
    String regionCode, {
    String? contentTypeId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection.where(
        'basic.lDongRegnCd',
        isEqualTo: regionCode,
      );
      if (contentTypeId != null) {
        query = query.where('basic.contentTypeId', isEqualTo: contentTypeId);
      } else {
        query = query.limit(_regionFetchSafetyLimit);
      }
      final snapshot = await query.get();
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
