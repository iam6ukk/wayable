import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screen/auth/login_screen.dart';
import '../screen/home_screen.dart';
import '../screen/myPage/mypage_screen.dart';
import '../screen/saveSpot/saved_list_screen.dart';
import '../screen/search/explore_screen.dart';
import '../screen/search/map_screen.dart';
import '../widgets/app_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_logo_banner.dart';

const _kTabTransitionDuration = Duration(milliseconds: 200);

/// 로그인한 회원만 접근 가능한 탭. 비회원이 누르면 탭 전환 대신 로그인 유도
/// 다이얼로그를 띄운다.
const _kMemberOnlyTabs = {BottomNavTab.myPage, BottomNavTab.savedList};

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
        primaryLabel: '로그인',
        secondaryLabel: '취소',
      );
      if (goLogin == true && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
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
      BottomNavTab.savedList => const SavedListScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const TopLogoBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: _kTabTransitionDuration,
                child: KeyedSubtree(
                  key: ValueKey(_currentTab),
                  child: _buildContent(),
                ),
              ),
            ),
            BottomNavBar(
              currentTab: _currentTab,
              onTabSelected: _handleTabSelected,
            ),
          ],
        ),
      ),
    );
  }
}
