import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/region/area_code.dart';
import '../../model/tour/tour_category.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/auth_provider.dart';
import '../../services/tour/tour_spot_service.dart';
import 'explore_filter_screen.dart';

const _kPrimaryBlue = Color(0xFF0065F4);
const _kSearchBarBg = Color(0x80D9D9D9);
const _kInactiveCircleBg = Color(0xFFF2F2F2);
const _kInactiveIconColor = Color(0xFF7D7D7D);
const _kFilterIconColor = Color(0xFFB7B7B7);
const _kHintTextColor = Color(0xFF6E6E6E);
const _kAddressTextColor = Color(0xFF5B5B5B);
const _kEmptyTextColor = Color(0xFFACACAC);

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.strollerCompanion,
  AccessibilityProfile.seniorCompanion,
];

const _kPageSize = 6;
const _kPageWindowSize = 5;

AccessibilityField? _fieldFromName(String name) {
  for (final field in AccessibilityField.values) {
    if (field.name == name) return field;
  }
  return null;
}

/// 맞춤 여행지 탐색 화면.
/// 검색 전에는 안내 문구만 보여주고, 검색하기를 누르면 Firestore tourSpots
/// 컬렉션을 조회해 결과를 6개씩 페이징으로 보여준다.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _service = TourSpotService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  /// 검색 API가 돌려준 원본(필터 적용 전) 결과. 칩을 지우는 등 필터만 바뀔 땐
  /// 재조회 없이 이 리스트를 다시 걸러서 즉시 반영한다.
  List<TourSpot> _rawResults = const [];
  List<TourSpot> _results = const [];
  int _currentPage = 1;
  bool _hasSearched = false;
  bool _isLoading = false;
  late Set<AccessibilityProfile> _activeProfiles;

  // 통합필터선택 화면에서 저장한 상세 필터.
  Map<AccessibilityProfile, Set<AccessibilityField>> _selectedFields = {};
  AreaCode? _selectedSido;
  SigunguCode? _selectedSigungu;
  Set<TourCategory> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    // 접근성 프로필/상세필드가 설정된 유저면 해당 대분류·필드를 기본
    // 활성화 상태로 보여주되, 이후에는 자유롭게 켜고 끌 수 있는 검색
    // 필터로 동작한다.
    final user = ref.read(authStateProvider).user;
    final savedProfileNames = user?.accessibilityProfiles ?? const [];
    _activeProfiles = AccessibilityProfile.values
        .where((profile) => savedProfileNames.contains(profile.name))
        .toSet();

    final savedFieldsByProfile = user?.accessibilityFieldsByProfile ?? const {};
    _selectedFields = {
      for (final profile in _activeProfiles)
        if (savedFieldsByProfile[profile.name] case final savedFields?)
          profile: savedFields.map(_fieldFromName).whereType<AccessibilityField>().toSet(),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// seniorCompanion은 별도 접근성 데이터 그룹이 없고 physicalAssist 필드 일부를
  /// 접근성 대분류/상세필드/지역/카테고리 필터를 모두 만족하는지 클라이언트 사이드에서 확인.
  /// (region/category까지 서버 쿼리에 넣으면 Firestore 복합 색인이 필요해지는데
  /// 아직 배포된 색인이 없어서, 넓게 가져온 뒤 여기서 전부 걸러낸다.)
  bool _matchesFilters(TourSpot spot) {
    // Firestore는 접두어 일치 쿼리만 지원해서 "박물관"으로 "대전선사박물관"을
    // 찾는 부분 일치 검색이 안 되므로, 검색어는 여기서 클라이언트 사이드로 확인한다.
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty && !spot.title.toLowerCase().contains(query)) return false;

    // 접근성은 대분류 간에도, 한 대분류 안의 상세필드 간에도 전부 OR로 묶는다.
    // (전부 만족하는 장소를 요구하면 대부분 0건이 되므로, "선택한 조건 중
    // 하나라도 있으면 통과"가 맞다.) seniorCompanion은 자체 필드 매핑
    // (AccessibilityFieldMapping)이 physicalAssist의 부분집합이라 별도 취급 없이
    // 그대로 순회해도 된다.
    if (_activeProfiles.isNotEmpty) {
      final acceptableFields = <AccessibilityField>{};
      for (final profile in _activeProfiles) {
        final chosen = _selectedFields[profile] ?? const {};
        if (chosen.isNotEmpty) {
          acceptableFields.addAll(chosen);
        } else {
          // 상세필드를 개별 선택하지 않았으면 "전체" = 이 대분류의 모든 필드가 대상.
          acceptableFields.addAll(AccessibilityFieldMapping.mapping[profile] ?? const []);
        }
      }
      if (!acceptableFields.any(spot.populatedFields.contains)) return false;
    }

    if (_selectedSido != null && spot.lDongRegnCd != _selectedSido!.code) return false;
    if (_selectedSigungu != null && !_selectedSigungu!.matches(spot.lDongSignguCd)) return false;

    if (_selectedCategories.isNotEmpty &&
        !_selectedCategories.any((c) => c.contentTypeId == spot.contentTypeId)) {
      return false;
    }

    return true;
  }

  /// 이미 가져온 원본 결과(_rawResults)를 현재 필터 상태로 다시 걸러 _results에
  /// 반영한다. 필터만 바뀌었을 땐 재조회 없이 이걸로 즉시 화면을 갱신한다.
  void _reapplyFilters() {
    if (!_hasSearched) return;
    _results = _rawResults.where(_matchesFilters).toList();
    _currentPage = 1;
  }

  Future<void> _toggleProfile(AccessibilityProfile profile) async {
    final isAdding = !_activeProfiles.contains(profile);

    setState(() {
      if (isAdding) {
        _activeProfiles.add(profile);
      } else {
        _activeProfiles.remove(profile);
        // 대분류가 꺼지면 그 안에서 골라둔 상세 필드도 같이 정리한다.
        _selectedFields.remove(profile);
      }
    });

    // 대분류를 새로 켜는(추가하는) 경우엔 이미 검색을 완료한 상태라면 다시
    // 검색한다. 끄는(제거하는) 경우엔 캐시에서 즉시 다시 걸러주면 된다.
    if (isAdding && _hasSearched) {
      await _handleSearch();
    } else {
      setState(_reapplyFilters);
    }
  }

  Future<void> _openFilterScreen() async {
    final result = await showModalBottomSheet<ExploreFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FCFF),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(31),
          topRight: Radius.circular(31),
        ),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ExploreFilterScreen(
          activeProfiles: _activeProfiles,
          initialSelectedFields: _selectedFields,
          initialSido: _selectedSido,
          initialSigungu: _selectedSigungu,
          initialCategories: _selectedCategories,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _selectedFields = result.selectedFields;
      _selectedSido = result.sido;
      _selectedSigungu = result.sigungu;
      _selectedCategories = result.categories;
    });

    // 이미 검색을 완료한 상태에서 필터를 추가/변경했다면 캐시가 아니라 새로
    // 검색해서 반영한다 (칩 x로 필터를 "빼는" 건 계속 캐시에서 즉시 처리).
    if (_hasSearched) {
      await _handleSearch();
    }
  }

  /// 무장애정보 상세필드/지역/카테고리 칩 목록. 각 칩의 x를 누르면 해당 조건만 해제한다.
  List<_ActiveFilterChip> get _activeFilterChips {
    final chips = <_ActiveFilterChip>[];

    for (final entry in _selectedFields.entries) {
      for (final field in entry.value) {
        chips.add(
          _ActiveFilterChip(
            label: field.label,
            onRemove: () => setState(() {
              final profile = entry.key;
              final fields = _selectedFields[profile];
              fields?.remove(field);
              // 이 대분류에서 명시적으로 골라뒀던 필드를 전부 지운 거면 "전체"로
              // 되돌아가는 게 아니라 대분류 자체를 꺼서 아이콘도 회색으로 바꾼다.
              if (fields != null && fields.isEmpty) {
                _selectedFields.remove(profile);
                _activeProfiles.remove(profile);
              }
              _reapplyFilters();
            }),
          ),
        );
      }
    }

    if (_selectedSido != null) {
      chips.add(
        _ActiveFilterChip(
          label: _selectedSido!.name,
          onRemove: () => setState(() {
            _selectedSido = null;
            _selectedSigungu = null;
            _reapplyFilters();
          }),
        ),
      );
    }

    if (_selectedSigungu != null) {
      chips.add(
        _ActiveFilterChip(
          label: _selectedSigungu!.name,
          onRemove: () => setState(() {
            _selectedSigungu = null;
            _reapplyFilters();
          }),
        ),
      );
    }

    for (final category in _selectedCategories) {
      chips.add(
        _ActiveFilterChip(
          label: category.label,
          onRemove: () => setState(() {
            _selectedCategories.remove(category);
            _reapplyFilters();
          }),
        ),
      );
    }

    return chips;
  }

  int get _totalPages => (_results.length / _kPageSize).ceil().clamp(1, 999999);

  List<TourSpot> get _pageItems {
    final start = (_currentPage - 1) * _kPageSize;
    if (start >= _results.length) return const [];
    final end = (start + _kPageSize).clamp(0, _results.length);
    return _results.sublist(start, end);
  }

  Future<void> _handleSearch() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _service.search();

    if (!mounted) return;
    setState(() {
      _rawResults = results;
      _results = results.where(_matchesFilters).toList();
      _currentPage = 1;
      _isLoading = false;
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() => _currentPage = page);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '맞춤 여행지 탐색',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              _SearchBar(controller: _searchController, onSubmitted: (_) => _handleSearch()),
              const SizedBox(height: 24),
              _AccessibilityProfileRow(
                activeProfiles: _activeProfiles,
                onToggle: _toggleProfile,
              ),
              const SizedBox(height: 20),
              _FilterSelectRow(onTap: _openFilterScreen),
              const SizedBox(height: 6),
              const Text(
                '지역과 카테고리를 선택할 수 있어요',
                style: TextStyle(fontSize: 12, color: _kHintTextColor),
              ),
              if (_activeFilterChips.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ActiveFilterChipsRow(chips: _activeFilterChips),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kPrimaryBlue.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '검색하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // 재검색 중에도 검색하기 버튼 위쪽은 물론, 결과 영역 자체도 그대로
              // 유지한 채 로딩 오버레이만 덧씌운다. _isLoading으로 이 영역을
              // 통째로 껐다 켜면 높이가 순간적으로 사라졌다 돌아오면서 화면
              // 전체가 아래로 밀렸다 올라오는 것처럼 보이는 문제가 있었다.
              Stack(
                children: [
                  Column(
                    children: [
                      if (!_hasSearched || _results.isEmpty)
                        const _EmptyResultState()
                      else ...[
                        _ResultGrid(items: _pageItems),
                        const SizedBox(height: 24),
                        _PaginationBar(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          onPageSelected: _goToPage,
                        ),
                      ],
                    ],
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFFF8FCFF).withValues(alpha: 0.85),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: _kPrimaryBlue),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScrollFab(icon: Icons.arrow_upward_rounded, onTap: _scrollToTop),
              const SizedBox(height: 11),
              _ScrollFab(icon: Icons.arrow_downward_rounded, onTap: _scrollToBottom),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveFilterChip {
  const _ActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;
}

class _ActiveFilterChipsRow extends StatelessWidget {
  const _ActiveFilterChipsRow({required this.chips});

  final List<_ActiveFilterChip> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) => _buildChip(chip)).toList(),
    );
  }

  Widget _buildChip(_ActiveFilterChip chip) {
    return Container(
      // x 아이콘 자체에 탭 영역 확보용 4px 패딩이 이미 있어서, 컨테이너 좌측
      // 여백을 오른쪽(10)보다 4 작게 둬야 아이콘부터 텍스트까지 실제 보이는
      // 여백이 좌우 10으로 맞는다.
      padding: const EdgeInsets.only(left: 6, right: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFF),
        border: Border.all(color: const Color(0xFF989898), width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: chip.onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: _kInactiveIconColor),
            ),
          ),
          const SizedBox(width: 2),
          Text(chip.label, style: const TextStyle(fontSize: 12, color: Colors.black)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _kSearchBarBg,
        borderRadius: BorderRadius.circular(37),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF697281)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: const InputDecoration(
                isCollapsed: true,
                hintText: '검색',
                hintStyle: TextStyle(fontSize: 16, color: Color(0xFF697281)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessibilityProfileRow extends StatelessWidget {
  const _AccessibilityProfileRow({required this.activeProfiles, required this.onToggle});

  final Set<AccessibilityProfile> activeProfiles;
  final ValueChanged<AccessibilityProfile> onToggle;

  @override
  Widget build(BuildContext context) {
    // 피그마 실측 기준 아이콘 원 52px + 사이 간격 19px 고정. spaceBetween으로
    // 화면 폭에 맞춰 늘리면 좌우 여백 값이 바뀔 때마다 간격이 따라 흔들려서
    // 고정 간격으로 바꿨다.
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _kProfileOrder.length; i++) ...[
            if (i > 0) const SizedBox(width: 19),
            _buildIcon(_kProfileOrder[i], activeProfiles.contains(_kProfileOrder[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(AccessibilityProfile profile, bool isActive) {
    return GestureDetector(
      onTap: () => onToggle(profile),
      behavior: HitTestBehavior.opaque,
      // 라벨 텍스트가 원(52px)보다 넓어서 그대로 두면 Column이 텍스트 폭만큼
      // 늘어나 옆 아이콘과의 실제 간격이 19px보다 벌어진다. 폭을 52로 고정해
      // 라벨이 필요하면 두 줄로 접히게 해서 원 기준 간격을 지킨다.
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _kPrimaryBlue : _kInactiveCircleBg,
              ),
              child: Icon(
                profile.icon,
                size: 28,
                color: isActive ? Colors.white : _kInactiveIconColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // 라벨의 띄어쓰기 위치에서 무조건 줄바꿈되도록 강제한다. 폭 기준
              // 자동 줄바꿈에 맡기면 한글은 띄어쓰기와 무관하게 아무 글자
              // 사이에서나 잘려서, "유모차 동반"이 "유모차 동"/"반"처럼
              // 단어 중간에서 갈라지는 문제가 있었다.
              profile.label.replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSelectRow extends StatelessWidget {
  const _FilterSelectRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '필터선택',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          SizedBox(width: 6),
          Icon(Icons.tune, size: 20, color: _kFilterIconColor),
        ],
      ),
    );
  }
}

class _EmptyResultState extends StatelessWidget {
  const _EmptyResultState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/explore_empty_search.png', width: 68, height: 68),
            const SizedBox(height: 24),
            const Text(
              '검색 결과가 없어요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _kEmptyTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.items});

  final List<TourSpot> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _ResultCard(spot: items[index]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.spot});

  final TourSpot spot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 172 / 113,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: spot.firstImage == null
                ? _buildImagePlaceholder()
                : Image.network(
                    spot.firstImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _buildImagePlaceholder(loading: true);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          spot.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          spot.addr1,
          style: const TextStyle(fontSize: 13, color: _kAddressTextColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (spot.supportedProfiles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: _kProfileOrder
                .where((p) => spot.supportedProfiles.contains(p))
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(p.icon, size: 16, color: _kInactiveIconColor),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePlaceholder({bool loading = false}) {
    return Container(
      color: _kInactiveCircleBg,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.image_not_supported_outlined, color: _kInactiveIconColor),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  List<int> get _visiblePages {
    var start = currentPage - (_kPageWindowSize ~/ 2);
    start = start.clamp(1, (totalPages - _kPageWindowSize + 1).clamp(1, totalPages));
    final end = (start + _kPageWindowSize - 1).clamp(1, totalPages);
    return [for (var p = start; p <= end; p++) p];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavTextButton(
          label: '이전',
          leadingIcon: Icons.chevron_left,
          enabled: currentPage > 1,
          onTap: () => onPageSelected(currentPage - 1),
        ),
        const SizedBox(width: 8),
        ..._visiblePages.map(
          (page) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _PageNumberButton(
              page: page,
              isSelected: page == currentPage,
              onTap: () => onPageSelected(page),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _NavTextButton(
          label: '다음',
          trailingIcon: Icons.chevron_right,
          enabled: currentPage < totalPages,
          onTap: () => onPageSelected(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.page,
    required this.isSelected,
    required this.onTap,
  });

  final int page;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: Colors.black, width: 1))
              : null,
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _NavTextButton extends StatelessWidget {
  const _NavTextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.black : Colors.black.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (leadingIcon != null) Icon(leadingIcon, size: 16, color: color),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: color)),
          if (trailingIcon != null) Icon(trailingIcon, size: 16, color: color),
        ],
      ),
    );
  }
}

class _ScrollFab extends StatelessWidget {
  const _ScrollFab({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F4F8),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: _kInactiveIconColor),
        ),
      ),
    );
  }
}
