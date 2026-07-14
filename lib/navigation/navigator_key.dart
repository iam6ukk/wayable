import 'package:flutter/material.dart';

/// 지연 실행되는 콜백(예: 다른 화면에서 나중에 호출되는 onComplete)에서
/// 이미 비활성화된 BuildContext 대신 안전하게 내비게이션하기 위한 전역 키.
final navigatorKey = GlobalKey<NavigatorState>();
