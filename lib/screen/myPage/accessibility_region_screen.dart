import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/region/area_code.dart';
import '../../providers/auth_provider.dart';
import '../../services/region/area_code_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/toast.dart';
import 'accessibility_subregion_screen.dart';

const _kCurrentStep = 3;
const _kTotalSteps = 4;

/// 접근성 프로필 설정 3단계: 관심 지역(시/도) 선택.
///
/// 2단계(편의정보 선택)에서 정리한 결과를 그대로 들고 있다가, 4단계(세부
/// 지역 선택)까지 마치면 그때 한 번에 Firestore에 저장한다.
class AccessibilityRegionScreen extends ConsumerStatefulWidget {
  const AccessibilityRegionScreen({
    super.key,
    required this.accessibilityFieldsByProfile,
    required this.onComplete,
  });

  final Map<String, List<String>> accessibilityFieldsByProfile;

  /// 설정을 마치거나(저장) 건너뛰었을 때 호출된다.
  final VoidCallback onComplete;

  @override
  ConsumerState<AccessibilityRegionScreen> createState() =>
      _AccessibilityRegionScreenState();
}

class _AccessibilityRegionScreenState
    extends ConsumerState<AccessibilityRegionScreen> {
  List<AreaCode> _areaCodes = const [];
  bool _loading = true;
  AreaCode? _selectedSido;

  @override
  void initState() {
    super.initState();
    _loadAreaCodes();
  }

  Future<void> _loadAreaCodes() async {
    final areaCodes = await AreaCodeRepository.load();
    if (!mounted) return;
    // 마이페이지 "프로필 수정하기"로 들어온 경우 기존에 저장했던 관심 지역을
    // 미리 선택해둔다. 신규 가입 온보딩 경로는 저장된 값이 없어 자연히
    // 미선택 상태로 시작된다.
    final savedSidoCode = ref.read(authStateProvider).user?.interestSidoCode;
    AreaCode? savedSido;
    for (final area in areaCodes) {
      if (area.code == savedSidoCode) {
        savedSido = area;
        break;
      }
    }
    setState(() {
      _areaCodes = areaCodes;
      _selectedSido = savedSido;
      _loading = false;
    });
  }

  void _selectSido(AreaCode area) {
    setState(() {
      _selectedSido = _selectedSido?.code == area.code ? null : area;
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

  void _handleNext() {
    final sido = _selectedSido;
    if (sido == null) {
      showAndroidToast(context, '관심 지역을 선택해 주세요.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccessibilitySubregionScreen(
          accessibilityFieldsByProfile: widget.accessibilityFieldsByProfile,
          sido: sido,
          onComplete: widget.onComplete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                              // arrow_back_ios_new 글리프는 아이콘 박스 안에서 살짝
                              // 오른쪽으로 치우쳐 그려져 있어, 아래 진행 숫자(n/4)와
                              // 좌측 라인을 맞추려면 그만큼 왼쪽으로 당겨줘야 한다.
                              Transform.translate(
                                offset: Offset(-4.w, 0),
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 16.r,
                                ),
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
                    '관심 지역을 선택해 주세요.',
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
                    '선택해 주신 지역에 맞춰 추천해 드려요.',
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
                    child: _buildSidoGrid(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.7.w),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.55.h,
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.7.r),
                        ),
                      ),
                      child: Text(
                        '다음으로',
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
            if (_loading) const Positioned.fill(child: LoadingOverlay()),
          ],
        ),
      ),
    );
  }

  /// 시/도 목록을 133×39 스타일의 2열 그리드로 보여준다(피그마 참고). 17개라
  /// 홀수라서 마지막 줄은 1개만 남는데, 그 한 줄은 가운데로 정렬한다.
  Widget _buildSidoGrid() {
    final rows = <Widget>[];
    for (var i = 0; i < _areaCodes.length; i += 2) {
      final hasSecond = i + 1 < _areaCodes.length;
      rows.add(
        Row(
          mainAxisAlignment: hasSecond
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.center,
          children: [
            _buildSidoChip(_areaCodes[i]),
            if (hasSecond) ...[
              SizedBox(width: 12.w),
              _buildSidoChip(_areaCodes[i + 1]),
            ],
          ],
        ),
      );
      if (i + 2 < _areaCodes.length) rows.add(SizedBox(height: 14.h));
    }
    return Column(children: rows);
  }

  Widget _buildSidoChip(AreaCode area) {
    final isSelected = _selectedSido?.code == area.code;
    return Semantics(
      label: area.name,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _selectSido(area),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 133.74.w,
          height: 39.39.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceCircle,
            borderRadius: BorderRadius.circular(34.r),
          ),
          child: Text(
            area.name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
