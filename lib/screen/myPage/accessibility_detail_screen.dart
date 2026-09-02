import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import 'accessibility_profile_save.dart';
import 'accessibility_region_screen.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.infantFamily,
  AccessibilityProfile.seniorCompanion,
];

const _kCurrentStep = 2;
const _kTotalSteps = 4;

class AccessibilityDetailScreen extends ConsumerStatefulWidget {
  const AccessibilityDetailScreen({
    super.key,
    required this.selectedProfiles,
    required this.onComplete,
  });

  final Set<AccessibilityProfile> selectedProfiles;

  /// 설정을 마치거나(저장) 건너뛰었을 때 호출된다.
  /// 접근성 프로필 화면 진입 경로에 따라 리턴 페이지 결정
  final VoidCallback onComplete;

  @override
  ConsumerState<AccessibilityDetailScreen> createState() =>
      _AccessibilityDetailScreenState();
}

class _AccessibilityDetailScreenState
    extends ConsumerState<AccessibilityDetailScreen> {
  // 대분류별로 독립된 필드 선택 상태를 가짐
  // 같은 무장애 편의정보를 공유하는 대분류(예: seniorCompanion과 physicalAssist)가 있어도
  // 한쪽에서 고른다고 다른 쪽 칩까지 같이 활성화되면 안 되기 때문
  final Map<AccessibilityProfile, Set<AccessibilityField>> _selectedFields = {};
  final Set<AccessibilityProfile> _selectAllProfiles = {};

  @override
  void initState() {
    super.initState();
    // 이전 단계에서 유지된 대분류는 기존에 저장했던 편의정보를 그대로 복원하고,
    // 이번에 새로 추가한 대분류는 저장된 값이 없으니 자연히 빈 상태로 시작된다
    // (온보딩 경로는 저장된 값 자체가 없어 전부 빈 상태).
    final saved =
        ref.read(authStateProvider).user?.accessibilityFieldsByProfile ??
        const {};
    for (final profile in widget.selectedProfiles) {
      final fieldNames = saved[profile.name];
      if (fieldNames == null) continue;
      if (fieldNames.isEmpty) {
        _selectAllProfiles.add(profile);
      } else {
        _selectedFields[profile] = fieldNames
            .map((name) => AccessibilityField.values.asNameMap()[name])
            .whereType<AccessibilityField>()
            .toSet();
      }
    }
  }

  void _toggleSelection(
    AccessibilityProfile profile,
    AccessibilityField field,
  ) {
    setState(() {
      final fields = _selectedFields.putIfAbsent(profile, () => {});
      if (fields.contains(field)) {
        fields.remove(field);
      } else {
        fields.add(field);
      }
      // 개별 필드를 직접 고르면 그 대분류의 '전체' 선택 해제
      _selectAllProfiles.remove(profile);
    });
  }

  void _toggleSelectAll(AccessibilityProfile profile) {
    setState(() {
      if (_selectAllProfiles.contains(profile)) {
        _selectAllProfiles.remove(profile);
      } else {
        _selectAllProfiles.add(profile);
        // '전체'를 고르면 그 대분류 안에서 개별로 골라둔 필드 해제
        _selectedFields[profile]?.clear();
      }
    });
  }

  // 건너뛰기 시 다이얼로그 — 지금까지(1단계에서 고른 유형) 입력한 내용은
  // 저장하고 나간다. 편의정보를 아직 안 고른 대분류는 _resolveFieldsByProfile이
  // 자동으로 빈 리스트(=전체)로 처리한다.
  Future<void> _handleSkip(BuildContext context) async {
    final skip = await showTwoButtonDialog(
      context,
      title: '건너뛰기 시 지금까지 설정한 내용만 저장됩니다.',
      content: '마이페이지에서 다시 수정할 수 있습니다.',
      primaryLabel: '건너뛰기',
      secondaryLabel: '취소',
    );
    if (skip != true || !context.mounted) return;
    await saveAccessibilityProfile(
      ref,
      accessibilityFieldsByProfile: _resolveFieldsByProfile(
        widget.selectedProfiles.toList(),
      ),
    );
    if (!context.mounted) return;
    widget.onComplete();
  }

  bool _hasSelectionFor(AccessibilityProfile profile) {
    if (_selectAllProfiles.contains(profile)) return true;
    return _selectedFields[profile]?.isNotEmpty ?? false;
  }

  /// profile별로 개별 선택된 필드를 그대로 저장한다 (빈 리스트 = "전체").
  /// 지체장애/고령자동반처럼 필드가 겹치는 profile이 있어서, 여기서 flat하게
  /// 합쳐버리면 나중에 어느 profile의 선택이었는지 복원할 수 없어진다.
  Map<String, List<String>> _resolveFieldsByProfile(
    List<AccessibilityProfile> profiles,
  ) {
    return {
      for (final profile in profiles)
        profile.name: (_selectedFields[profile] ?? const {})
            .map((f) => f.name)
            .toList(),
    };
  }

  /// 실제 저장은 3·4단계(관심 지역 선택)를 마친 뒤 4단계에서 한 번에 이뤄진다
  /// (편의정보+지역을 같은 Firestore 문서 갱신으로 묶기 위함). 여기서는 이번
  /// 단계에서 고른 편의정보를 profile별 Map으로 정리해 다음 단계로 넘긴다.
  Future<void> _handleNext(List<AccessibilityProfile> profiles) async {
    final hasUnselectedProfile = profiles.any(
      (profile) => !_hasSelectionFor(profile),
    );

    if (hasUnselectedProfile) {
      final confirmed = await showTwoButtonDialog(
        context,
        content: '편의 정보를 선택하지 않은 경우,\n전체 항목을 기준으로 정보가 제공됩니다.',
        primaryLabel: '확인',
        secondaryLabel: '취소',
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccessibilityRegionScreen(
          accessibilityFieldsByProfile: _resolveFieldsByProfile(profiles),
          onComplete: widget.onComplete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderedProfiles = _kProfileOrder
        .where((profile) => widget.selectedProfiles.contains(profile))
        .toList();

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
                          // 치우쳐 그려져 있어, 아래 진행 숫자(1/4)와 좌측 라인을
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
                  backgroundColor: const Color(0xFFE3E3E3),
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            SizedBox(height: 26.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                '필요하신 편의 정보를 선택해 주세요.',
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
                '선택해 주신 항목 기준으로 정보를 안내해 드려요.',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: ListView.separated(
                  itemCount: orderedProfiles.length,
                  separatorBuilder: (_, _) => SizedBox(height: 22.h),
                  itemBuilder: (context, index) =>
                      _buildSection(orderedProfiles[index]),
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
                  onPressed: () => _handleNext(orderedProfiles),
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
      ),
    );
  }

  Widget _buildSection(AccessibilityProfile profile) {
    final fields = AccessibilityFieldMapping.mapping[profile] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(profile.icon, size: 24.r, color: AppColors.primary),
            ),
            SizedBox(width: 6.w),
            Text(
              profile.label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            _buildAllChip(profile),
            ...fields.map((field) => _buildChip(profile, field)),
          ],
        ),
      ],
    );
  }

  Widget _buildAllChip(AccessibilityProfile profile) {
    final isSelected = _selectAllProfiles.contains(profile);
    return _chip(
      label: '전체',
      isSelected: isSelected,
      onTap: () => _toggleSelectAll(profile),
    );
  }

  Widget _buildChip(AccessibilityProfile profile, AccessibilityField field) {
    final isSelected = _selectedFields[profile]?.contains(field) ?? false;
    return _chip(
      label: field.label,
      isSelected: isSelected,
      onTap: () => _toggleSelection(profile, field),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceCircle,
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Text(
            label,
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
