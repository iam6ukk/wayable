import 'package:flutter/material.dart';

/// 지연 실행되는 콜백(예: 다른 화면에서 나중에 호출되는 onComplete)에서
/// 이미 비활성화된 BuildContext 대신 안전하게 내비게이션하기 위한 전역 키.
final navigatorKey = GlobalKey<NavigatorState>();

/// 카카오맵(하이브리드 컴포지션) 네이티브 플랫폼 뷰는 MapScreen이 MainShell
/// 안에서 Offstage로만 숨겨질 때는 잘 가려지지만, MainShell 위에 다른 화면이
/// Navigator.push로 얹히는 경우(예: SpotDetailScreen)는 탭 전환이 아니라서
/// Offstage 상태가 안 바뀐다 — 그 사이 네이티브 뷰가 Flutter의 페인트 순서를
/// 무시하고 위에 얹힌 화면 위로 그대로 비쳐 보이는 문제가 있다. MapScreen이
/// RouteAware로 이 옵저버를 구독해 자신 위에 다른 라우트가 덮이는 시점을
/// 감지하고, 그동안은 플랫폼 뷰 자체를 아예 안 그리도록 한다.
final routeObserver = RouteObserver<PageRoute>();
