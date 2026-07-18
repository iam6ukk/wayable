import 'package:flutter/material.dart';
import '../screen/home_screen.dart';
import '../screen/myPage/mypage_screen.dart';
import '../screen/saveSpot/saved_list_screen.dart';
import '../screen/search/explore_screen.dart';
import '../screen/search/map_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_logo_banner.dart';

const _kTabTransitionDuration = Duration(milliseconds: 200);

/// 하단 탭 화면들의 공용 셸. 상단 배너와 하단 탭 바는 고정한 채
/// 선택된 탭에 따라 콘텐츠 영역만 페이드 인/아웃으로 교체한다.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = BottomNavTab.home});

  final BottomNavTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late BottomNavTab _currentTab = widget.initialTab;

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
              onTabSelected: (tab) => setState(() => _currentTab = tab),
            ),
          ],
        ),
      ),
    );
  }
}
