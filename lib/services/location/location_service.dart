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
        ),
      );
    } catch (e) {
      AppLogger.error('[Location] 위치 조회 실패', error: e);
      return null;
    }
  }
}
