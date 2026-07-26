import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/region/area_code.dart';
import '../../model/tour/tour_category.dart';
import '../../services/region/area_code_repository.dart';

const _kPrimaryBlue = Color(0xFF0065F4);
const _kChipInactiveBorder = Color(0xFFC8C8C8);
const _kDividerColor = Color(0xFFE3E3E3);

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.strollerCompanion,
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
        backgroundColor: const Color(0xFFF8FCFF),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(),
              TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: const Color(0xFF9D9D9D),
                indicatorColor: Colors.black,
                // 탭 인디케이터 각 탭이 차지하는 영역 전체 너비로 맞춤
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: _tabLabel('무장애정보', _accessibilitySelectionCount)),
                  Tab(text: _tabLabel('지역', _regionSelectionCount)),
                  Tab(text: _tabLabel('카테고리', _categories.length)),
                ],
              ),
              Divider(height: 1, color: _kDividerColor),
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
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 8.w, 0),
      child: Row(
        children: [
          Text(
            '통합필터선택',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB0B0B0),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFFB7B7B7)),
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
            '탐색 화면에서 접근성 대분류를 먼저 선택해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF9D9D9D)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(20.r),
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
            Icon(profile.icon, size: 20.r, color: _kPrimaryBlue),
            SizedBox(width: 6.w),
            Text(
              '무장애정보 > ${profile.label}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
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
    if (_loadingAreaCodes) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.all(20.r),
      children: [
        Text(
          '시/도',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
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
      padding: EdgeInsets.all(20.r),
      child: Wrap(
        spacing: 10.w,
        runSpacing: 10.h,
        children: TourCategory.values
            .map(
              (category) => _chip(
                label: category.label,
                isSelected: _categories.contains(category),
                onTap: () => _toggleCategory(category),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      child: Row(
        children: [
          SizedBox(
            height: 53.h,
            child: OutlinedButton.icon(
              onPressed: _handleReset,
              icon: Icon(Icons.refresh, size: 18.r, color: Colors.black),
              label: Text(
                '초기화',
                style: TextStyle(fontSize: 15.sp, color: Colors.black),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                backgroundColor: const Color(0xFFEFF1F4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SizedBox(
              height: 53.h,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
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
    // 선택 시 글자 굵기(w400->w600)만으로도 칩 너비가 늘어나서, 화면 폭이
    // 좁은 기기에서는 카테고리를 2개 이상 고를 때마다 Wrap 줄바꿈 위치가
    // 흔들리는 문제가 있었다. 보이지 않는 굵은 글씨를 밑에 깔아 항상 그
    // 너비만큼 자리를 예약해두면, 실제 글씨는 얇든 굵든 같은 칩 크기 안에서
    // 렌더링되어 선택 여부와 무관하게 레이아웃이 고정된다.
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? Colors.black : _kChipInactiveBorder,
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: Text(
                label,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
