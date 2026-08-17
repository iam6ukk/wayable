import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

enum BottomNavTab {
  explore, // 맞춤 여행지 탐색
  map, // 지도 기반 탐색
  home, // 홈 메인
  bookmark, // 북마크(저장목록)
  myPage, // 마이페이지
}

extension _BottomNavTabX on BottomNavTab {
  IconData get icon => switch (this) {
    BottomNavTab.explore => Icons.search_outlined,
    BottomNavTab.map => Icons.pin_drop_outlined,
    BottomNavTab.home => Icons.home_outlined,
    BottomNavTab.bookmark => Icons.bookmark_border,
    BottomNavTab.myPage => Icons.person_outlined,
  };

  // 스크린 리더가 읽어줄 탭 이름. 화면 표시용 라벨이 따로 없는 아이콘 전용
  // 탭바라, semanticLabel 목적으로만 쓴다.
  String get semanticLabel => switch (this) {
    BottomNavTab.explore => '맞춤 여행지 탐색',
    BottomNavTab.map => '지도 기반 탐색',
    BottomNavTab.home => '홈',
    BottomNavTab.bookmark => '저장목록',
    BottomNavTab.myPage => '마이페이지',
  };
}

/// 하단 탭 메뉴 공통 컴포넌트. 화면들이 currentTab과 onTabSelected만
/// 넘겨주면 되도록 재사용 가능한 형태로 제공한다.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final BottomNavTab currentTab;
  final ValueChanged<BottomNavTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    // 시스템 제스처/내비게이션 바 영역은 배경색만 이어지도록 하단 인셋만큼
    // 추가 패딩을 주고, 실제 탭 영역은 안드로이드 표준 높이(56dp)로 고정한다.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        // kBottomNavigationBarHeight(Material 기본 56dp)는 뷰포트 스케일과
        // 무관한 고정값이다. 아이콘(28.r)처럼 스케일을 따라 커지는 콘텐츠와
        // 같이 두면, 세로 스케일이 큰 기기(태블릿)에서는 아이콘이 이 고정
        // 높이에 거의 꽉 차 위아래 여백이 없어 보이고, 스케일이 1에 가까운
        // 기기(폰)에서는 여백이 넉넉해 보여 기기마다 탭 바 안쪽 여백이
        // 달라 보였다. 탭 바 높이도 같은 축(.h)으로 스케일해야 아이콘과의
        // 여백 비율이 기기와 무관하게 항상 동일하게 유지된다.
        height: kBottomNavigationBarHeight.h,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: BottomNavTab.values
              .map((tab) => _buildTabIcon(tab))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTabIcon(BottomNavTab tab) {
    final isSelected = tab == currentTab;

    return Semantics(
      label: tab.semanticLabel,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTabSelected(tab),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48.w,
          height: kBottomNavigationBarHeight.h,
          child: Center(
            child: Icon(
              tab.icon,
              size: 28.r,
              color: isSelected
                  ? AppColors.bottomNavActive
                  : AppColors.bottomNavInactive,
            ),
          ),
        ),
      ),
    );
  }
}
