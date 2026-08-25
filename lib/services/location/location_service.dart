import 'package:geolocator/geolocator.dart';
import 'package:wayable/utils/app_logger.dart';

/// 사용자 GPS 위치 조회. 위치 서비스가 꺼져있거나 권한이 거부되면 null을 반환하고,
/// 호출부(홈 화면)는 이 경우 랜덤 지역으로 폴백한다.
class LocationService {
  // 홈/지도/저장목록 화면이 각자 새 GPS fix를 기다리면(최대 8초) 탭을 오갈
  // 때마다 반복해서 느려진다. 짧은 시간 안에는 실측이 크게 달라지지 않는다고
  // 보고, 마지막으로 잡은 위치를 static으로 앱 전체가 공유해 재사용한다.
  static Position? _cachedPosition;

  // 수도권은 대중교통으로 30분이면 인접 구/시로도 이동 가능하지만, 지방은
  // 시군구 하나를 넘어가는 데 보통 30분 이상 걸린다. "오늘 발견"류 추천
  // 기능은 위치가 며칠씩 정밀할 필요가 없어 이 정도 오차는 감수할 만하다.
  static const _cacheFreshDuration = Duration(minutes: 30);

  bool _isFresh(Position position) =>
      DateTime.now().difference(position.timestamp) < _cacheFreshDuration;

  /// [forceRefresh]가 true면 캐시가 신선해도 무시하고 항상 실측한다.
  /// "내 위치" 버튼처럼 사용자가 명시적으로 지금 위치를 다시 요청한
  /// 경우에 쓴다.
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    final cached = _cachedPosition;
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached;
    }

    final position = await _fetchCurrentPosition();
    if (position != null) {
      _cachedPosition = position;
    }
    return position;
  }

  Future<Position?> _fetchCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        AppLogger.debug('[Location] 위치 서비스 꺼짐');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppLogger.debug('[Location] 권한 거부: $permission');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      // GPS가 실내 등에서 새 fix를 못 잡으면 timeLimit 없이는 무한 대기했다
      // (지도 화면이 계속 서울 기본값에 머무는 원인). 타임아웃/실패 시에도
      // 기기가 예전에 잡아둔 위치가 있으면 그거라도 쓰는 게 기본 위치보다
      // 낫다 — 다만 getLastKnownPosition() 자체엔 타임아웃이 없어 기기에
      // 따라 응답이 아예 없을 수 있고(에뮬레이터에서 실제로 1분 넘게 무한
      // 대기하는 걸 확인함), 반환값도 몇 시간~며칠 전에 잡힌 오래된 위치일
      // 수 있는데 검증 없이 그대로 믿으면 "GPS 허용했는데 엉뚱한 지역이
      // 나온다"는 결과로 이어진다. 그래서 이 폴백도 타임아웃을 걸고,
      // _isFresh로 신선도까지 확인한다.
      AppLogger.warning('[Location] 위치 조회 실패, 마지막 위치로 폴백 ($e)');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 3),
        );
        if (lastKnown != null && _isFresh(lastKnown)) {
          return lastKnown;
        }
        AppLogger.debug('[Location] 마지막 위치가 없거나 너무 오래됨');
        return null;
      } catch (e) {
        AppLogger.warning('[Location] 마지막 위치 조회도 실패 ($e)');
        return null;
      }
    }
  }
}
