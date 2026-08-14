import 'package:flutter_riverpod/legacy.dart';
import '../model/accessibility/accessibility_profile.dart';
import '../widgets/bottom_nav_bar.dart';

/// MainShell 위에 push된 화면(예: SpotDetailScreen)에서 하단 탭을 눌렀을 때,
/// 그냥 pop만 하면 이전에 있던 탭으로 돌아갈 뿐 실제로 그 탭으로 전환되지
/// 않는다. 이 프로바이더에 원하는 탭을 담아두면 MainShell이 감지해서 바로
/// 그 탭으로 전환한 뒤 값을 비운다.
final tabSwitchRequestProvider = StateProvider<BottomNavTab?>((ref) => null);

/// 홈 화면의 "무장애 여행" 카드를 눌렀을 때, 맞춤 여행지 탐색 탭이 어떤
/// 접근성 대분류(상세 카테고리는 전체)로 바로 검색된 상태를 보여줄지 담아둔다.
/// ExploreScreen이 이 값을 소비한 뒤 다시 null로 비운다.
final pendingAccessibilityRequestProvider =
    StateProvider<AccessibilityProfile?>((ref) => null);

/// 지도 탭에서 검색 결과 바텀시트가 떠 있는 동안 true. MainShell이 이 값을
/// 보고 하단 탭 바를 숨긴다(피그마 지도기반 검색 결과 화면에는 하단 탭 바가
/// 없음 — 바텀시트가 화면 하단까지 차지하는 전체화면에 가까운 레이아웃).
final mapResultsActiveProvider = StateProvider<bool>((ref) => false);
