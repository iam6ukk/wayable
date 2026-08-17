import 'package:flutter/foundation.dart';

/// 앱 전역 로깅 유틸리티
///
/// - kDebugMode에서만 출력되므로 release 빌드(배포용 앱)에서는 동작 안 함
/// - 토큰, 비밀키, 전체 응답 객체 등 민감 정보는 어떤 레벨에서도 출력하면 안 됨
///
/// 사용 예:
/// ```dart
/// AppLogger.debug('[Auth] Kakao login success');
/// AppLogger.error('[Auth] Kakao login failed', error: e);
/// ```
class AppLogger {
  AppLogger._();

  /// 흐름 추적용 (성공 여부, 화면 이동 여부, provider 값 등)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// 정상 동작이지만 기록해둘 만한 정보 (Firestore 저장 성공 등)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// 비정상이지만 앱 동작에 치명적이지 않은 상황
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }

  /// 에러 발생 시. error 객체 전체를 그대로 출력하지 않도록
  /// 타입 + 메시지(toString())만 추출해 출력
  /// (예외 객체 안에 토큰, 응답 바디 등 민감 정보가 들어있을 수 있기 때문)
  static void error(String message, {Object? error}) {
    if (kDebugMode) {
      final detail = error == null ? '' : ' (${error.runtimeType}: $error)';
      debugPrint('[ERROR] $message$detail');
    }
  }
}
