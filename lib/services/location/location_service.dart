import 'package:geolocator/geolocator.dart';
import 'package:wayable/utils/app_logger.dart';

/// 사용자 GPS 위치 조회. 위치 서비스가 꺼져있거나 권한이 거부되면 null을 반환하고,
/// 호출부(홈 화면)는 이 경우 랜덤 지역으로 폴백한다.
class LocationService {
  Future<Position?> getCurrentPosition() async {
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
      // 기기가 예전에 잡아둔 위치가 있으면 그거라도 쓰는 게 기본 위치보다 낫다.
      AppLogger.warning('[Location] 위치 조회 실패, 마지막 위치로 폴백 ($e)');
      return await Geolocator.getLastKnownPosition();
    }
  }
}
