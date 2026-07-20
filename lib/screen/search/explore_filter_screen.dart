import 'package:flutter/material.dart';
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
  final Map<AccessibilityProfile, Set<AccessibilityField>> initialSelectedFields;
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
      for (final entry in widget.initialSelectedFields.entries) entry.key: {...entry.value},
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
                indicatorColor: _kPrimaryBlue,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: _tabLabel('무장애정보', _accessibilitySelectionCount)),
                  Tab(text: _tabLabel('지역', _regionSelectionCount)),
                  Tab(text: _tabLabel('카테고리', _categories.length)),
                ],
              ),
              const Divider(height: 1, color: _kDividerColor),
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

  int get _regionSelectionCount => (_sido != null ? 1 : 0) + (_sigungu != null ? 1 : 0);

  String _tabLabel(String label, int count) => count > 0 ? '$label $count' : label;

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(
        children: [
          const Text(
            '통합필터선택',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFB0B0B0)),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '탐색 화면에서 접근성 대분류를 먼저 선택해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9D9D9D)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orderedProfiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 28),
      itemBuilder: (context, index) => _buildProfileSection(orderedProfiles[index]),
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
            Icon(profile.icon, size: 20, color: _kPrimaryBlue),
            const SizedBox(width: 6),
            Text(
              '무장애정보 > ${profile.label}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(label: '전체', isSelected: selected.isEmpty, onTap: () => _selectAllFields(profile)),
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
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '시/도',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
          const SizedBox(height: 28),
          const Text(
            '2차 지역',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          SizedBox(
            height: 53,
            child: OutlinedButton.icon(
              onPressed: _handleReset,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.black),
              label: const Text('초기화', style: TextStyle(fontSize: 15, color: Colors.black)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                backgroundColor: const Color(0xFFEFF1F4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 53,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : _kChipInactiveBorder,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
