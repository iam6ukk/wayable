import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/region/area_code.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/toast.dart';

const _kCurrentStep = 4;
const _kTotalSteps = 4;

/// 관심 지역의 세부 지역(시/군/구)을 최소 1개, 최대 3개까지 고를 수 있다.
const _kMaxSigungu = 3;

/// 접근성 프로필 설정 4단계(마지막): 세부 지역 선택 + 최종 저장.
///
/// 1~3단계에서 모은 편의정보/관심 지역(시/도)을 여기서 한 번에 Firestore에
/// 저장한다 — accessibility_detail_screen.dart의 기존 저장 로직을 그대로
/// 가져오되, 관심 지역 필드를 같이 얹는다.
class AccessibilitySubregionScreen extends ConsumerStatefulWidget {
  const AccessibilitySubregionScreen({
    super.key,
    required this.accessibilityFieldsByProfile,
    required this.sido,
    required this.onComplete,
  });

  final Map<String, List<String>> accessibilityFieldsByProfile;
  final AreaCode sido;

  /// 설정을 마치거나(저장) 건너뛰었을 때 호출된다.
  final VoidCallback onComplete;

  @override
  ConsumerState<AccessibilitySubregionScreen> createState() =>
      _AccessibilitySubregionScreenState();
}

class _AccessibilitySubregionScreenState
    extends ConsumerState<AccessibilitySubregionScreen> {
  final _userService = UserService();
  final Set<SigunguCode> _selected = {};

  @override
  void initState() {
    super.initState();
    // 마이페이지 "프로필 수정하기"로 들어왔고 지금 고른 시/도가 기존에
    // 저장했던 시/도와 같다면, 그 안에서 저장했던 세부 지역도 미리 선택해둔다.
    final user = ref.read(authStateProvider).user;
    if (user?.interestSidoCode != widget.sido.code) return;
    final savedCodes = user?.interestSigunguCodes ?? const [];
    _selected.addAll(
      widget.sido.sigungu.where((sg) => savedCodes.contains(sg.code)),
    );
  }

  void _toggleSelection(SigunguCode sigungu) {
    setState(() {
      if (_selected.contains(sigungu)) {
        _selected.remove(sigungu);
        return;
      }
      if (_selected.length >= _kMaxSigungu) {
        showAndroidToast(context, '최대 $_kMaxSigungu개까지 선택할 수 있어요.');
        return;
      }
      _selected.add(sigungu);
    });
  }

  // 건너뛰기 시 다이얼로그
  Future<void> _handleSkip(BuildContext context) async {
    final skip = await showTwoButtonDialog(
      context,
      title: '접근성 프로필을 설정하면 나에게 맞는\n장소를 쉽게 찾을 수 있습니다.',
      content: '마이페이지에서 언제든 접근성 프로필을\n수정할 수 있습니다.',
      primaryLabel: '건너뛰기',
      secondaryLabel: '취소',
    );
    if (skip != true || !context.mounted) return;
    widget.onComplete();
  }

  Future<void> _handleSave() async {
    if (_selected.isEmpty) {
      showAndroidToast(context, '지역을 최소 1개 이상 선택해 주세요.');
      return;
    }

    final currentUser = ref.read(authStateProvider).user;
    if (currentUser == null) {
      AppLogger.error('[AccessibilitySubregionScreen] 로그인된 유저 정보가 없어 저장을 건너뜀');
      if (!mounted) return;
      widget.onComplete();
      return;
    }

    final updatedUser = currentUser.copyWith(
      accessibilityFieldsByProfile: widget.accessibilityFieldsByProfile,
      interestSidoCode: widget.sido.code,
      interestSigunguCodes: _selected.map((sg) => sg.code).toList(),
    );

    try {
      await _userService.updateUser(updatedUser);
      ref.read(authStateProvider.notifier).setUser(updatedUser);
    } catch (e) {
      if (!mounted) return;
      await showInfoDialog(context, content: '저장에 실패했습니다.\n다시 시도해 주세요.');
      return;
    }

    if (!mounted) return;
    await showInfoDialog(
      context,
      content: '접근성 프로필이 저장됐습니다.\n마이페이지에서 수정할 수 있습니다.',
    );

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SizedBox(
                height: 24.h,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.bottomNavActive,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // arrow_back_ios_new 글리프는 아이콘 박스 안에서 살짝 오른쪽으로
                          // 치우쳐 그려져 있어, 아래 진행 숫자(n/4)와 좌측 라인을
                          // 맞추려면 그만큼 왼쪽으로 당겨줘야 한다.
                          Transform.translate(
                            offset: Offset(-4.w, 0),
                            child: Icon(Icons.arrow_back_ios_new, size: 16.r),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '이전',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: '$_kCurrentStep',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(text: '/$_kTotalSteps'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _handleSkip(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textTertiary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('건너뛰기', style: TextStyle(fontSize: 12.sp)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.5.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: LinearProgressIndicator(
                  value: _kCurrentStep / _kTotalSteps,
                  minHeight: 4.h,
                  backgroundColor: AppColors.toggleUnselectedBackground,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            SizedBox(height: 26.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                '${widget.sido.name}의 세부 지역을 선택해 주세요.',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 11.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                '최대 $_kMaxSigungu개까지 선택할 수 있어요.',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: widget.sido.sigungu
                      .map((sigungu) => _buildChip(sigungu))
                      .toList(),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.7.w),
              child: SizedBox(
                width: double.infinity,
                height: 48.55.h,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.7.r),
                    ),
                  ),
                  child: Text(
                    '저장하기',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(SigunguCode sigungu) {
    final isSelected = _selected.contains(sigungu);
    return Semantics(
      label: sigungu.name,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _toggleSelection(sigungu),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceCircle,
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Text(
            sigungu.name,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
