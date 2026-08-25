import 'package:flutter_riverpod/legacy.dart';
import '../model/accessibility/accessibility_profile.dart';
import '../widgets/bottom_nav_bar.dart';

/// MainShell 위에 push된 화면(예: SpotDetailScreen)에서 하단 탭을 눌렀을 때,
/// 그냥 pop만 하면 이전에 있던 탭으로 돌아갈 뿐 실제로 그 탭으로 전환되지
/// 않는다. 이 프로바이더에 원하는 탭을 담아두면 MainShell이 감지해서 바로
/// 그 탭으로 전환한 뒤 값을 비운다.
final tabSwitchRequestProvider = StateProvider<BottomNavTab?>((ref) => null);

/// 로그인한 회원만 접근 가능한 탭. 비회원이 누르면 탭 전환 대신 로그인 유도
/// 다이얼로그를 띄운다 — MainShell 하단 탭 바뿐 아니라, 그 위에 push된
/// 화면(SpotDetailScreen 등)이 자체적으로 그리는 BottomNavBar도 같은 기준을
/// 써야 한다(각자 따로 판단하면 한쪽만 고쳤을 때 다시 새는 문제가 생긴다).
const kMemberOnlyTabs = {BottomNavTab.myPage, BottomNavTab.bookmark};

/// 홈 화면의 "무장애 여행" 카드를 눌렀을 때, 맞춤 여행지 탐색 탭이 어떤
/// 접근성 대분류(상세 카테고리는 전체)로 바로 검색된 상태를 보여줄지 담아둔다.
/// ExploreScreen이 이 값을 소비한 뒤 다시 null로 비운다.
final pendingAccessibilityRequestProvider =
    StateProvider<AccessibilityProfile?>((ref) => null);

/// 지도 탭에서 검색 결과 바텀시트가 떠 있는 동안 true. MainShell이 이 값을
/// 보고 하단 탭 바를 숨긴다(피그마 지도기반 검색 결과 화면에는 하단 탭 바가
/// 없음 — 바텀시트가 화면 하단까지 차지하는 전체화면에 가까운 레이아웃).
final mapResultsActiveProvider = StateProvider<bool>((ref) => false);

/// 지금 활성 탭 화면이 자신의 로컬 UI 상태(펼쳐진 필터, 편집 모드 등) 때문에
/// 시스템 뒤로가기를 직접 소비하고 있는 동안 true. MainShell도 같은 라우트에
/// PopScope를 두고 있어서, 이 값을 확인하지 않으면 화면의 로컬 뒤로가기
/// 처리(예: 폴더 편집 모드 빠져나가기)와 MainShell의 탭 이력 되돌리기가 같은
/// 뒤로가기 한 번에 동시에 일어나 버린다(로컬 처리는 안 보이고 탭만
/// 전환된 것처럼 보이는 버그). 활성 탭 화면은 자신의 로컬 PopScope의
/// canPop과 정확히 같은 조건으로 이 값을 갱신하고, 비활성화되면 반드시
/// false로 되돌려야 한다(안 그러면 백그라운드 탭의 오래된 값이 남아 있는
/// 다른 탭의 정상적인 뒤로가기까지 막아버린다).
final localBackInterceptActiveProvider = StateProvider<bool>((ref) => false);
