import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/navigation_provider.dart';
import '../screen/auth/login_screen.dart';
import '../screen/home_screen.dart';
import '../screen/myPage/mypage_screen.dart';
import '../screen/bookmark/bookmark_screen.dart';
import '../screen/search/explore_screen.dart';
import '../screen/search/map_screen.dart';
import '../widgets/app_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_logo_banner.dart';

const _kTabTransitionDuration = Duration(milliseconds: 200);

/// 로그인한 회원만 접근 가능한 탭. 비회원이 누르면 탭 전환 대신 로그인 유도
/// 다이얼로그를 띄운다.
const _kMemberOnlyTabs = {BottomNavTab.myPage, BottomNavTab.bookmark};

/// 하단 탭 화면들의 공용 셸. 상단 배너와 하단 탭 바는 고정한 채
/// 선택된 탭에 따라 콘텐츠 영역만 페이드 인/아웃으로 교체한다.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = BottomNavTab.home});

  final BottomNavTab initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late BottomNavTab _currentTab = widget.initialTab;

  Future<void> _handleTabSelected(BottomNavTab tab) async {
    final isGuest = ref.read(authStateProvider).user == null;
    if (isGuest && _kMemberOnlyTabs.contains(tab)) {
      final goLogin = await showTwoButtonDialog(
        context,
        content: '회원에게만 제공되는 기능입니다.\n로그인 하시겠습니까?',
        primaryLabel: '로그인하기',
        secondaryLabel: '취소',
      );
      if (goLogin == true && context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }
    setState(() => _currentTab = tab);
  }

  Widget _buildContent() {
    return switch (_currentTab) {
      BottomNavTab.explore => const ExploreScreen(),
      BottomNavTab.map => const MapScreen(),
      BottomNavTab.home => const HomeScreen(),
      BottomNavTab.myPage => const MyPageScreen(),
      BottomNavTab.bookmark => const SavedListScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // 저장목록 탭은 아직 선택하지 않았어도 로그인 상태라면 여기서 미리
    // 구독을 시작해둔다 — 탭을 처음 누르는 순간부터 Firestore 왕복(폴더
    // 목록/여행지 목록 조회)을 시작하면 그동안 화면이 비어 보이므로, 다른
    // 탭을 보고 있는 동안 미리 받아둬서 탭을 눌렀을 때는 이미 준비된 값을
    // 바로 보여줄 수 있게 한다.
    ref.watch(bookmarkProvider);

    // SpotDetailScreen처럼 MainShell 위에 push된 화면에서 하단 탭을 눌렀을
    // 때, 그냥 pop만 하면 이전에 보고 있던 탭으로 돌아갈 뿐 실제로 그 탭으로
    // 전환되지 않는다. 그런 화면은 pop과 함께 이 프로바이더에 원하는 탭을
    // 담아두고, 여기서 감지해서 바로 그 탭으로 전환한다.
    ref.listen<BottomNavTab?>(tabSwitchRequestProvider, (_, requestedTab) {
      if (requestedTab == null) return;
      setState(() => _currentTab = requestedTab);
      ref.read(tabSwitchRequestProvider.notifier).state = null;
    });

    // 지도 탭에서 검색 결과 바텀시트가 뜨면(피그마 831:763 등) 하단 탭 바가
    // 없는 전체화면에 가까운 레이아웃이 된다.
    final hideBottomNav =
        _currentTab == BottomNavTab.map && ref.watch(mapResultsActiveProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      // 기본값(true)이면 키보드가 열고 닫힐 때마다 이 셸 전체(배너+콘텐츠+
      // 하단 탭바)가 매 프레임 리사이즈되면서, 탐색 화면의 하단 고정 스크롤
      // 버튼(Positioned bottom)이 그 리사이즈를 따라 눈에 띄게 움직여 화면이
      // 덜컥거리는 것처럼 보였다. 키보드 입력이 있는 화면은 탐색 탭 검색창
      // 하나뿐이고 위쪽에 있어 키보드에 가려질 일도 없어서 꺼도 안전하다.
      resizeToAvoidBottomInset: false,
      // resizeToAvoidBottomInset만으로는 부족했다 — Scaffold body는 리사이즈
      // 안 해도, 탐색 화면 검색창(TextField)이 포커스를 받으면 그 안의
      // EditableText가 MediaQuery.viewInsets.bottom(키보드 높이)을 그대로
      // 보고 "키보드에 안 가리게" 스스로 상위 스크롤뷰를 위로 스크롤시켜서,
      // 검색 제출 시 화면이 살짝 올라갔다 내려오는 것처럼 보였다. 이 셸
      // 아래로는 keyboard inset 자체를 안 보이게 없애서 그 자동 스크롤이
      // 아예 발생하지 않게 한다.
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              // 지도 화면은 자체 상단 배경 밴드(검색창+카테고리)가 상태바
              // 인셋까지 직접 챙기는 피그마 시안이라, 여기서 로고 배너를
              // 또 얹으면 파란 헤더가 두 겹으로 보인다.
              if (_currentTab != BottomNavTab.map) const TopLogoBanner(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _kTabTransitionDuration,
                  // AnimatedSwitcher의 기본 layoutBuilder는 Stack(alignment:
                  // center)라서, 탭 콘텐츠가 이 Expanded 영역보다 짧으면(예:
                  // 탐색 화면이 검색 전/결과 없음 상태일 때) 위쪽이 아니라
                  // 세로 가운데로 정렬되어 배너 바로 아래에 큰 여백이 생기고,
                  // 검색 결과가 생겨 콘텐츠가 길어지면 그 여백이 줄면서
                  // 화면이 위로 올라가는 것처럼 보였다. 항상 위쪽 기준으로
                  // 붙도록 정렬을 바꾼다.
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_currentTab),
                    child: _buildContent(),
                  ),
                ),
              ),
              if (!hideBottomNav)
                BottomNavBar(
                  currentTab: _currentTab,
                  onTabSelected: _handleTabSelected,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
