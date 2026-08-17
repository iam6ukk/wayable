import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/region/area_code.dart';
import '../../model/tour/tour_category.dart';
import '../../services/region/area_code_repository.dart';
import '../../widgets/loading_overlay.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.infantFamily,
  AccessibilityProfile.seniorCompanion,
];

/// 통합필터선택 화면에서 저장한 결과.
class ExploreFilterResult {
  const ExploreFilterResult({
    required this.selectedFields,
    required this.sido,
    required this.sigungu,
    required this.categories,
  });

  final Map<AccessibilityProfile, Set<AccessibilityField>> selectedFields;
  final AreaCode? sido;
  final SigunguCode? sigungu;
  final Set<TourCategory> categories;
}

/// 맞춤 여행지 탐색의 상세 필터 선택 화면 (무장애정보/지역/카테고리 3탭).
/// 무장애정보 탭은 기본 화면에서 활성화된 접근성 대분류에 한해서만 상세 필드를 보여준다.
class ExploreFilterScreen extends StatefulWidget {
  const ExploreFilterScreen({
    super.key,
    required this.activeProfiles,
    required this.initialSelectedFields,
    required this.initialSido,
    required this.initialSigungu,
    required this.initialCategories,
  });

  final Set<AccessibilityProfile> activeProfiles;
  final Map<AccessibilityProfile, Set<AccessibilityField>>
  initialSelectedFields;
  final AreaCode? initialSido;
  final SigunguCode? initialSigungu;
  final Set<TourCategory> initialCategories;

  @override
  State<ExploreFilterScreen> createState() => _ExploreFilterScreenState();
}

class _ExploreFilterScreenState extends State<ExploreFilterScreen> {
  late Map<AccessibilityProfile, Set<AccessibilityField>> _selectedFields;
  AreaCode? _sido;
  SigunguCode? _sigungu;
  late Set<TourCategory> _categories;

  List<AreaCode> _areaCodes = const [];
  bool _loadingAreaCodes = true;

  @override
  void initState() {
    super.initState();
    _selectedFields = {
      for (final entry in widget.initialSelectedFields.entries)
        entry.key: {...entry.value},
    };
    _sido = widget.initialSido;
    _sigungu = widget.initialSigungu;
    _categories = {...widget.initialCategories};
    _loadAreaCodes();
  }

  Future<void> _loadAreaCodes() async {
    final areaCodes = await AreaCodeRepository.load();
    if (!mounted) return;
    setState(() {
      _areaCodes = areaCodes;
      _loadingAreaCodes = false;
    });
  }

  void _toggleField(AccessibilityProfile profile, AccessibilityField field) {
    setState(() {
      final fields = _selectedFields.putIfAbsent(profile, () => {});
      if (fields.contains(field)) {
        fields.remove(field);
      } else {
        fields.add(field);
      }
    });
  }

  void _selectAllFields(AccessibilityProfile profile) {
    setState(() => _selectedFields[profile] = {});
  }

  void _selectSido(AreaCode area) {
    setState(() {
      if (_sido?.code == area.code) {
        _sido = null;
        _sigungu = null;
      } else {
        _sido = area;
        _sigungu = null;
      }
    });
  }

  void _selectSigungu(SigunguCode sigungu) {
    setState(() {
      _sigungu = _sigungu?.code == sigungu.code ? null : sigungu;
    });
  }

  void _toggleCategory(TourCategory category) {
    setState(() {
      if (_categories.contains(category)) {
        _categories.remove(category);
      } else {
        _categories.add(category);
      }
    });
  }

  void _handleReset() {
    setState(() {
      _selectedFields = {};
      _sido = null;
      _sigungu = null;
      _categories = {};
    });
  }

  void _handleSave() {
    Navigator.of(context).pop(
      ExploreFilterResult(
        selectedFields: _selectedFields,
        sido: _sido,
        sigungu: _sigungu,
        categories: _categories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bottomSheetBackground,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  // 필터 항목 탭
                  TabBar(
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textTertiary,
                    indicatorColor: AppColors.textPrimary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        text: _tabLabel('편의정보', _accessibilitySelectionCount),
                      ),
                      Tab(text: _tabLabel('지역', _regionSelectionCount)),
                      Tab(text: _tabLabel('카테고리', _categories.length)),
                    ],
                  ),
                  Divider(height: 1, color: AppColors.faintDivider),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAccessibilityTab(),
                        _buildRegionTab(),
                        _buildCategoryTab(),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
              if (_loadingAreaCodes)
                const Positioned.fill(child: LoadingOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  int get _accessibilitySelectionCount =>
      _selectedFields.values.where((fields) => fields.isNotEmpty).length;

  int get _regionSelectionCount =>
      (_sido != null ? 1 : 0) + (_sigungu != null ? 1 : 0);

  String _tabLabel(String label, int count) =>
      count > 0 ? '$label $count' : label;

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 8.w, 0),
      child: Row(
        children: [
          Text(
            '통합필터선택',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '닫기',
            icon: Icon(
              Icons.close,
              size: 24.r,
              color: AppColors.navIconInactive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityTab() {
    final orderedProfiles = _kProfileOrder
        .where((profile) => widget.activeProfiles.contains(profile))
        .toList();

    if (orderedProfiles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Text(
            '탐색 화면에서 접근성 대분류를 먼저 선택해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textQuaternary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(35.w, 15.h, 35.w, 20.h),
      itemCount: orderedProfiles.length,
      separatorBuilder: (_, _) => SizedBox(height: 28.h),
      itemBuilder: (context, index) =>
          _buildProfileSection(orderedProfiles[index]),
    );
  }

  Widget _buildProfileSection(AccessibilityProfile profile) {
    final fields = AccessibilityFieldMapping.mapping[profile] ?? const [];
    final selected = _selectedFields[profile] ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(profile.icon, size: 24.r, color: AppColors.primary),
            SizedBox(width: 6.w),
            Text(
              '편의정보 > ${profile.label}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 11.h),
        Wrap(
          spacing: 5.5.w,
          runSpacing: 7.3.h,
          children: [
            _chip(
              label: '전체',
              isSelected: selected.isEmpty,
              onTap: () => _selectAllFields(profile),
            ),
            ...fields.map(
              (field) => _chip(
                label: field.label,
                isSelected: selected.contains(field),
                onTap: () => _toggleField(profile, field),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegionTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(35.w, 15.h, 35.w, 20.h),
      children: [
        Text(
          '시/도',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 11.h),
        Wrap(
          spacing: 5.5.w,
          runSpacing: 7.3.h,
          children: _areaCodes
              .map(
                (area) => _chip(
                  label: area.name,
                  isSelected: _sido?.code == area.code,
                  onTap: () => _selectSido(area),
                ),
              )
              .toList(),
        ),
        if (_sido != null) ...[
          SizedBox(height: 28.h),
          Text(
            '2차 지역',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 11.h),
          Wrap(
            spacing: 5.5.w,
            runSpacing: 7.3.h,
            children: _sido!.sigungu
                .map(
                  (sigungu) => _chip(
                    label: sigungu.name,
                    isSelected: _sigungu?.code == sigungu.code,
                    onTap: () => _selectSigungu(sigungu),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryTab() {
    return Padding(
      padding: EdgeInsets.fromLTRB(35.w, 15.h, 35.w, 20.h),
      child: Wrap(
        spacing: 5.5.w,
        runSpacing: 7.3.h,
        children: [
          for (final category in TourCategory.values)
            _chip(
              label: category.label,
              isSelected: _categories.contains(category),
              onTap: () => _toggleCategory(category),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 14.h),
      child: Row(
        children: [
          SizedBox(
            height: 45.8.h,
            child: OutlinedButton.icon(
              onPressed: _handleReset,
              icon: Icon(
                Icons.refresh,
                size: 20.r,
                color: AppColors.bottomNavActive,
              ),
              label: Text(
                '초기화',
                style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.boldDivider),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.7.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SizedBox(
              height: 46.7.h,
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
                  '저장',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
          padding: EdgeInsets.symmetric(horizontal: 17.w, vertical: 5.5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.boldDivider,
              width: isSelected ? 1 : 0.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
