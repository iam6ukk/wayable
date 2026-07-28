import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/region/area_code.dart';
import '../../model/tour/tour_category.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/auth_provider.dart';
import '../../services/tour/tour_spot_service.dart';
import '../../widgets/image_placeholder.dart';
import 'explore_filter_screen.dart';
import 'spot_detail_screen.dart';

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
  AccessibilityProfile.infantFamily,
  AccessibilityProfile.seniorCompanion,
];

const _kPageSize = 6;
const _kPageWindowSize = 5;

/// 페이지를 넘길 때마다 서버(Cloud Function)를 매번 호출하면 왕복 지연이
/// 그대로 체감되므로, 한 번에 [_kBatchPages]페이지치([_kBatchSize]건)를 받아
/// 캐시해두고 그 안에서는 네트워크 요청 없이 즉시 페이지를 넘긴다. 이 범위를
/// 벗어날 때만(11페이지째 등) 다음 배치를 새로 요청한다.
const _kBatchPages = 10;
const _kBatchSize = _kPageSize * _kBatchPages;

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

  /// 서버(Cloud Function)가 검색어/필터를 다 적용해서 돌려준 현재 배치
  /// (최대 _kBatchSize건). [_pageItems]가 이 안에서 _kPageSize씩 잘라 보여준다.
  List<TourSpot> _currentBatch = const [];
  /// 지금 [_currentBatch]가 몇 번째 배치인지(1-based). _goToPage에서 이미
  /// 캐시된 배치 범위 안이면 재요청 없이 즉시 페이지만 바꾼다.
  int _loadedBatchNumber = 0;
  int _totalCount = 0;
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
          profile: savedFields
              .map(_fieldFromName)
              .whereType<AccessibilityField>()
              .toSet(),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 검색어/지역/카테고리/시군구/접근성 상세필드 필터를 전부 Cloud Function
  /// (searchTourSpots)에 넘겨 서버에서 거른 결과를 받으므로, 여기서는 선택된
  /// 접근성 대분류·상세필드를 서버가 이해하는 필드명(AccessibilityField.name)
  /// 목록으로 펼치기만 한다.
  ///
  /// 접근성은 대분류 간에도, 한 대분류 안의 상세필드 간에도 전부 OR로 묶는다.
  /// (전부 만족하는 장소를 요구하면 대부분 0건이 되므로, "선택한 조건 중
  /// 하나라도 있으면 통과"가 맞다.) seniorCompanion은 자체 필드 매핑
  /// (AccessibilityFieldMapping)이 physicalAssist의 부분집합이라 별도 취급 없이
  /// 그대로 순회해도 된다.
  List<String>? get _acceptableFieldNames {
    if (_activeProfiles.isEmpty) return null;
    final acceptableFields = <AccessibilityField>{};
    for (final profile in _activeProfiles) {
      final chosen = _selectedFields[profile] ?? const {};
      if (chosen.isNotEmpty) {
        acceptableFields.addAll(chosen);
      } else {
        // 상세필드를 개별 선택하지 않았으면 "전체" = 이 대분류의 모든 필드가 대상.
        acceptableFields.addAll(
          AccessibilityFieldMapping.mapping[profile] ?? const [],
        );
      }
    }
    return acceptableFields.map((field) => field.name).toList();
  }

  // 검색어 입력, 필터 추가/삭제는 전부 상태만 바꾸고, 실제 조회는 사용자가
  // "검색하기"를 눌렀을 때(_handleSearch)만 실행한다 — 필터를 하나씩
  // 만지작거릴 때마다 바로 로딩이 뜨고 결과가 바뀌면 아직 조건을 다 정하지
  // 않은 상태에서도 검색이 실행된 것처럼 보여 흐름이 어색하다.
  void _toggleProfile(AccessibilityProfile profile) {
    setState(() {
      if (_activeProfiles.contains(profile)) {
        _activeProfiles.remove(profile);
        // 대분류가 꺼지면 그 안에서 골라둔 상세 필드도 같이 정리한다.
        _selectedFields.remove(profile);
      } else {
        _activeProfiles.add(profile);
      }
    });
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
  }

  /// 무장애정보 상세필드/지역/카테고리 칩 목록. 각 칩의 x를 누르면 해당 조건만 해제한다.
  List<_ActiveFilterChip> get _activeFilterChips {
    final chips = <_ActiveFilterChip>[];

    for (final entry in _selectedFields.entries) {
      for (final field in entry.value) {
        chips.add(
          _ActiveFilterChip(
            label: field.label,
            onRemove: () {
              setState(() {
                final profile = entry.key;
                final fields = _selectedFields[profile];
                fields?.remove(field);
                // 이 대분류에서 명시적으로 골라뒀던 필드를 전부 지운 거면 "전체"로
                // 되돌아가는 게 아니라 대분류 자체를 꺼서 아이콘도 회색으로 바꾼다.
                if (fields != null && fields.isEmpty) {
                  _selectedFields.remove(profile);
                  _activeProfiles.remove(profile);
                }
              });
            },
          ),
        );
      }
    }

    if (_selectedSido != null) {
      chips.add(
        _ActiveFilterChip(
          label: _selectedSido!.name,
          onRemove: () {
            setState(() {
              _selectedSido = null;
              _selectedSigungu = null;
            });
          },
        ),
      );
    }

    if (_selectedSigungu != null) {
      chips.add(
        _ActiveFilterChip(
          label: _selectedSigungu!.name,
          onRemove: () {
            setState(() => _selectedSigungu = null);
          },
        ),
      );
    }

    for (final category in _selectedCategories) {
      chips.add(
        _ActiveFilterChip(
          label: category.label,
          onRemove: () {
            setState(() => _selectedCategories.remove(category));
          },
        ),
      );
    }

    return chips;
  }

  int get _totalPages => (_totalCount / _kPageSize).ceil().clamp(1, 999999);

  int _batchNumberForPage(int page) => ((page - 1) ~/ _kBatchPages) + 1;

  List<TourSpot> get _pageItems {
    final localIndex = (_currentPage - 1) % _kBatchPages;
    final start = localIndex * _kPageSize;
    if (start >= _currentBatch.length) return const [];
    final end = (start + _kPageSize).clamp(0, _currentBatch.length);
    return _currentBatch.sublist(start, end);
  }

  /// [batchNumber]번째 배치(_kBatchSize건)를 서버(Cloud Function)에서 받아온다.
  Future<void> _fetchBatch(int batchNumber) async {
    final result = await _service.search(
      keyword: _searchController.text.trim(),
      regionCode: _selectedSido?.code,
      categoryIds: _selectedCategories.isEmpty
          ? null
          : _selectedCategories.map((c) => c.contentTypeId).toList(),
      acceptableFields: _acceptableFieldNames,
      sigunguMemberCodes: _selectedSigungu?.memberCodes,
      page: batchNumber,
      pageSize: _kBatchSize,
    );

    if (!mounted) return;
    setState(() {
      _currentBatch = result.spots;
      _totalCount = result.totalCount;
      _loadedBatchNumber = batchNumber;
    });
  }

  /// 검색어/필터가 바뀌었을 때 1페이지부터 새로 검색한다.
  Future<void> _handleSearch() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    await _fetchBatch(1);

    if (!mounted) return;
    setState(() {
      _currentPage = 1;
      _isLoading = false;
    });
  }

  /// [page]로 이동한다. 이미 캐시된 배치 범위 안이면 서버 요청 없이 즉시
  /// 전환하고, 배치 경계를 넘어갈 때만 다음 배치를 새로 받아온다.
  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;

    final batchNumber = _batchNumberForPage(page);
    if (batchNumber == _loadedBatchNumber) {
      setState(() => _currentPage = page);
    } else {
      setState(() => _isLoading = true);
      await _fetchBatch(batchNumber);
      if (!mounted) return;
      setState(() {
        _currentPage = page;
        _isLoading = false;
      });
    }

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
        // SingleChildScrollView를 non-positioned 자식으로 그대로 두면 이 Stack
        // 자체의 높이가 "뷰포트 전체"가 아니라 "콘텐츠 실제 높이"만큼으로
        // 정해진다(짧으면 줄고, 넘치면 뷰포트 한도까지 늘어남). 아래
        // Positioned(bottom:20)인 상하단 이동 버튼은 그 가변적인 Stack 바닥을
        // 기준으로 위치하다 보니, 필터 칩이 늘어 스크롤이 트리거될 때마다
        // Stack이 커지면서 버튼도 같이 아래로 밀려 보였다. Positioned.fill로
        // 감싸 이 자식을 Stack 크기 계산에서 빼면 Stack이 항상 뷰포트 전체
        // 높이를 차지하게 되어, 버튼이 콘텐츠 길이와 무관하게 완전히 고정된다.
        Positioned.fill(child: _buildScrollableContent()),
        Positioned(
          right: 20.w,
          bottom: 20.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScrollFab(icon: Icons.arrow_upward_rounded, onTap: _scrollToTop),
              SizedBox(height: 11.h),
              _ScrollFab(
                icon: Icons.arrow_downward_rounded,
                onTap: _scrollToBottom,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 검색어~검색하기 버튼까지, 결과 유무와 무관하게 항상 보이는 상단 콘텐츠.
  List<Widget> _topContent() {
    return [
      const Text(
        '맞춤 여행지 탐색',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 20),
      _SearchBar(
        controller: _searchController,
        onSubmitted: (_) => _handleSearch(),
      ),
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
          // 로딩 중에도 onPressed를 null로 바꾸지 않는다 — null이 되면
          // disabledBackgroundColor로 버튼 색이 로딩 내내 바뀐 채로 유지돼
          // 버튼이 눌렸을 때의 순간적인 탭 반응처럼 보이지 않는다. 중복 실행
          // 방지는 _handleSearch 내부의 _isLoading 가드로 처리한다.
          onPressed: _handleSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            '검색하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ];
  }

  Widget _loadingOverlay() {
    // 반투명 배경으로 아래 목록을 가려야 검색 중이라는 게 명확해진다 —
    // 배경 없이 스피너만 띄우면 이전 검색 결과가 그대로 선명하게 보여서
    // 새로 검색 중인지 구분이 안 됐다.
    return Positioned.fill(
      child: Container(
        color: Colors.white.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _kPrimaryBlue),
      ),
    );
  }

  Widget _buildScrollableContent() {
    // 결과 그리드(_ResultGrid)는 내부적으로 GridView를 쓰는데, GridView 같은
    // Viewport 기반 위젯은 IntrinsicHeight 조상 아래 있으면 "does not support
    // returning intrinsic dimensions" 예외를 던지며 이 서브트리 전체가 렌더링에
    // 실패한다(그래서 검색 결과가 있을 때 화면이 통째로 하얗게 비어 보였다).
    // 그래서 결과가 없을 때(=GridView가 트리에 없을 때)만 IntrinsicHeight로
    // 남은 공간을 계산해 정중앙 정렬하고, 결과가 있을 땐 그런 트릭 없이 원래
    // 방식(그냥 스크롤 가능한 Column)으로 그린다.
    if (!_hasSearched || _totalCount == 0) {
      return LayoutBuilder(
        builder: (context, viewportConstraints) {
          const verticalPadding = 24.0 + 36.0;
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight - verticalPadding,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._topContent(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Stack(
                        children: [
                          // 검색을 아직 한 번도 안 한 초기 상태와 로딩 중에는
                          // "검색 결과가 없어요"를 보여주면 안 된다 — 그건
                          // 실제로 검색을 마쳤는데 0건일 때만 맞는 문구다.
                          if (_hasSearched && !_isLoading)
                            const Center(child: _EmptyResultState()),
                          if (_isLoading) _loadingOverlay(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._topContent(),
          const SizedBox(height: 24),
          Stack(
            children: [
              Column(
                children: [
                  _ResultGrid(items: _pageItems),
                  const SizedBox(height: 24),
                  _PaginationBar(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onPageSelected: _goToPage,
                  ),
                ],
              ),
              if (_isLoading) _loadingOverlay(),
            ],
          ),
        ],
      ),
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
          Text(
            chip.label,
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
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
  const _AccessibilityProfileRow({
    required this.activeProfiles,
    required this.onToggle,
  });

  final Set<AccessibilityProfile> activeProfiles;
  final ValueChanged<AccessibilityProfile> onToggle;

  @override
  Widget build(BuildContext context) {
    // 피그마 실측 기준 아이콘 원 52px + 사이 간격 19px. 393dp 기준 디자인
    // 값이라 그대로 쓰면 5개(52*5 + 19*4 = 336)가 360dp 폭 기기(좌우 패딩
    // 24*2 제외 가용폭 312)에서 24px 오버플로우한다. ScreenUtil로 실제
    // 화면 폭 대비 비례 스케일해 좁은 기기에서도 넘치지 않게 한다.
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _kProfileOrder.length; i++) ...[
            if (i > 0) SizedBox(width: 19.w),
            _buildIcon(
              _kProfileOrder[i],
              activeProfiles.contains(_kProfileOrder[i]),
            ),
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
        width: 52.w,
        child: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _kPrimaryBlue : _kInactiveCircleBg,
              ),
              child: Icon(
                profile.icon,
                size: 28.w,
                color: isActive ? Colors.white : _kInactiveIconColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              // 라벨의 띄어쓰기 위치에서 무조건 줄바꿈되도록 강제한다. 폭 기준
              // 자동 줄바꿈에 맡기면 한글은 띄어쓰기와 무관하게 아무 글자
              // 사이에서나 잘려서, "유모차 동반"이 "유모차 동"/"반"처럼
              // 단어 중간에서 갈라지는 문제가 있었다.
              profile.label.replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
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
    // 호출부(Expanded 안의 Center)가 이미 정중앙 정렬을 담당하므로, 여기서는
    // 콘텐츠 폭만큼만 차지하면 된다. 상하 여백은 필터 칩이 한 줄 붙어도
    // 남은 공간의 intrinsic 높이 계산에서 스크롤을 유발하지 않도록 작게 둔다.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/explore_empty_search.png',
            width: 68,
            height: 68,
          ),
          const SizedBox(height: 24),
          const Text(
            '검색 결과가 없어요',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _kEmptyTextColor,
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
      behavior: HitTestBehavior.opaque,
      child: Column(
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
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
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
      ),
    );
  }

  Widget _buildImagePlaceholder({bool loading = false}) {
    if (loading) {
      return Container(
        color: _kInactiveCircleBg,
        alignment: Alignment.center,
        child: SizedBox(
          width: 20.r,
          height: 20.r,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return const ImagePlaceholder();
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
    start = start.clamp(
      1,
      (totalPages - _kPageWindowSize + 1).clamp(1, totalPages),
    );
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
            color: isSelected
                ? Colors.black
                : Colors.black.withValues(alpha: 0.5),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
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
