import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/toast.dart';
import 'accessibility_detail_screen.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.infantFamily,
  AccessibilityProfile.seniorCompanion,
];

const _kCurrentStep = 1;
const _kTotalSteps = 2;

class AccessibilityScreen extends ConsumerStatefulWidget {
  const AccessibilityScreen({super.key, required this.onComplete});

  /// 설정을 마치거나(저장) 건너뛰었을 때 호출된다. 진입 경로에 따라
  /// 호출부에서 홈 화면 이동, 이전 화면으로 복귀 등을 결정한다.
  final VoidCallback onComplete;

  @override
  ConsumerState<AccessibilityScreen> createState() =>
      _AccessibilityScreenState();
}

class _AccessibilityScreenState extends ConsumerState<AccessibilityScreen> {
  final Set<AccessibilityProfile> _selectedProfiles = {};

  void _toggleSelection(AccessibilityProfile profile) {
    setState(() {
      if (_selectedProfiles.contains(profile)) {
        _selectedProfiles.remove(profile);
      } else {
        _selectedProfiles.add(profile);
      }
    });
  }

  Future<void> _handleSkip(BuildContext context) async {
    final skip = await showTwoButtonDialog(
      context,
      title: '접근성 프로필을 설정하면 나에게 맞는 장소를 쉽게 찾을 수 있어요.',
      content: '마이페이지에서 언제든 접근성 프로필을 수정할 수 있습니다.',
      primaryLabel: '건너뛰기',
      secondaryLabel: '취소하기',
    );
    if (skip != true || !context.mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(authStateProvider).user?.nickname ?? '게스트';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              SizedBox(height: 24.h),
              SizedBox(height: 16.h),
              Row(
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 16.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: '$_kCurrentStep',
                          style: const TextStyle(color: Color(0xFF0065F4)),
                        ),
                        TextSpan(text: '/$_kTotalSteps'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _handleSkip(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9A9A9A),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('건너뛰기', style: TextStyle(fontSize: 12.sp)),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: LinearProgressIndicator(
                  value: _kCurrentStep / _kTotalSteps,
                  minHeight: 4.h,
                  backgroundColor: const Color(0xFFE3E3E3),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0065F4)),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                '$nickname님의 관심유형을 선택해주세요',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '선택해주신 관심유형에 맞춰 추천해드려요',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: const Color(0xFF6F6F6F),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOption(_kProfileOrder[0]),
                          _buildOption(_kProfileOrder[1]),
                        ],
                      ),
                      SizedBox(height: 32.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOption(_kProfileOrder[2]),
                          _buildOption(_kProfileOrder[3]),
                        ],
                      ),
                      SizedBox(height: 32.h),
                      _buildOption(_kProfileOrder[4]),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 53.h,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedProfiles.isEmpty) {
                      showAndroidToast(context, '하나 이상의 관심 유형을 선택해주세요.');
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccessibilityDetailScreen(
                          selectedProfiles: _selectedProfiles,
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0065F4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    '다음으로',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(AccessibilityProfile profile) {
    final isSelected = _selectedProfiles.contains(profile);

    return GestureDetector(
      onTap: () => _toggleSelection(profile),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 110.w,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 90.r,
              height: 90.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF0065F4)
                    : const Color(0xFFF2F2F2),
              ),
              child: Icon(
                profile.icon,
                size: 48.r,
                color: isSelected ? Colors.white : const Color(0xFF7D7D7D),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              profile.label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
