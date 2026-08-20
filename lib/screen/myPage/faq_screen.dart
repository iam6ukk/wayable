import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/faq/faq_category.dart';
import '../../model/faq/faq_data.dart';
import '../../model/faq/faq_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/chevron_icon.dart';
import '../../widgets/top_logo_banner.dart';
import '../auth/login_screen.dart';

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  FaqCategory? _selectedCategory;
  final Set<String> _expandedQuestions = {};

  /// 하단 탭 바 아이콘 탭. 회원 전용 탭(저장목록/마이페이지)은 MainShell의
  /// _handleTabSelected와 같은 기준으로 비회원을 먼저 걸러야 한다 — 여기서
  /// 그냥 tabSwitchRequestProvider만 채우고 pop하면 그 판단 없이 바로
  /// 저장목록/마이페이지 화면이 열려버린다.
  Future<void> _handleBottomNavTap(BottomNavTab tab) async {
    final isGuest = ref.read(authStateProvider).user == null;
    if (isGuest && kMemberOnlyTabs.contains(tab)) {
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

    ref.read(tabSwitchRequestProvider.notifier).state = tab;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == null
        ? faqItems
        : faqItems.where((item) => item.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const TopLogoBanner(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      '자주 묻는 질문',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: '전체',
                          category: null,
                          width: 50.w,
                        ),
                        for (final category in FaqCategory.values) ...[
                          SizedBox(width: 8.w),
                          _buildFilterChip(
                            label: category.label,
                            category: category,
                            width: _chipWidth(category),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: AppColors.mutedDivider, height: 1.h),
                      itemBuilder: (context, index) =>
                          _buildFaqTile(filteredItems[index]),
                    ),
                  ),
                ],
              ),
            ),
            BottomNavBar(
              currentTab: BottomNavTab.myPage,
              onTabSelected: _handleBottomNavTap,
            ),
          ],
        ),
      ),
    );
  }

  double _chipWidth(FaqCategory category) => switch (category) {
    FaqCategory.accessibilityProfile => 94.w,
    FaqCategory.explore => 50.w,
    FaqCategory.savedSpot => 50.w,
    FaqCategory.etc => 50.w,
  };

  Widget _buildFilterChip({
    required String label,
    required FaqCategory? category,
    required double width,
  }) {
    final isSelected = _selectedCategory == category;
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedCategory = category;
          _expandedQuestions.clear();
        }),
        child: Container(
          width: width,
          height: 30.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.boldDivider,
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile(FaqItem item) {
    final isExpanded = _expandedQuestions.contains(item.question);
    return Theme(
      // 필터가 바뀌면 같은 위치의 타일이라도 완전히 새로 만들어져서(=펼침
      // 상태 초기화) 이전 카테고리에서 펼쳐뒀던 항목이 엉뚱한 위치에서
      // 펼쳐진 채로 남아있지 않는다.
      key: ValueKey('${_selectedCategory}_${item.question}'),
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // ExpansionTile 헤더(ListTile) 한 줄의 최소 높이는 기본적으로
        // Material의 고정 최소 탭 영역(kMinInteractiveDimension=48, 뷰포트
        // 스케일과 무관)을 따른다. 제목 글자(13.sp)는 뷰포트 스케일을 따라
        // 커지는데 이 최소 높이는 고정이라, 태블릿처럼 세로 스케일이 큰
        // 기기에서는 글자가 그 고정 여백을 다 잠식해 위아래 간격이 좁아
        // 보였다. tilePadding으로 여백을 무작정 더하면 이미 적당했던
        // 폰에서도 같이 늘어나버리므로, 대신 이 최소 높이 자체를 .h로
        // 스케일해서 폰에서의 비율은 그대로 유지한 채(48→48.h, 거의 차이
        // 없음) 태블릿에서만 실질적으로 커지게 한다.
        minTileHeight: kMinInteractiveDimension.h,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        trailing: ChevronIcon(
          pointsUp: isExpanded,
          color: AppColors.textTertiary,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedQuestions.add(item.question);
            } else {
              _expandedQuestions.remove(item.question);
            }
          });
        },
        title: Text(
          'Q. ${item.question}',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.bottomSheetBackground,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              item.answer,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
