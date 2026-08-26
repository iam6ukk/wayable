import 'package:cached_network_image/cached_network_image.dart';
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
import '../../providers/navigation_provider.dart';
import '../../services/region/area_code_repository.dart';
import '../../services/tour/tour_spot_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';
import '../../utils/image_cache_size.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/scroll_fab.dart';
import 'explore_filter_screen.dart';
import 'spot_detail_screen.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.infantFamily,
  AccessibilityProfile.seniorCompanion,
];

// 한 페이지에 보여줄 항목 개수
const _kPageSize = 6;
const _kPageWindowSize = 5;

/// 한 번에 [_kBatchPages]페이지치([_kBatchSize]건)를 받아
/// 캐시해두고 그 안에서는 네트워크 요청 없이 즉시 페이지를 넘김
/// 이 범위를 벗어날 때만(11페이지째 등) 다음 배치를 새로 요청
const _kBatchPages = 10;
const _kBatchSize = _kPageSize * _kBatchPages;

AccessibilityField? _fieldFromName(String name) {
  for (final field in AccessibilityField.values) {
    if (field.name == name) return field;
  }
  return null;
}

/// 맞춤 여행지 탐색 화면
/// 검색 전에는 안내 문구만 보여주고, 검색하기를 누르면 Firestore tourSpots
/// 컬렉션을 조회해 결과를 6개씩 페이징으로 보여준다.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, required this.isActive});

  /// 지금 하단 탭에서 실제로 보이고 있는 탭인지. MainShell이 탭을 떠나도
  /// 이 화면을 지우지 않고 숨겨만 두므로(다른 탭 전환 시 상태 보존 목적),
  /// 대신 이 값이 false로 바뀌는 시점을 감지해 검색 상태를 기본값으로
  /// 되돌린다(지도 탭과 동일한 패턴).
  final bool isActive;

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
  Set<SigunguCode> _selectedSigungus = {};
  Set<TourCategory> _selectedCategories = {};

  // 홈 화면 무장애 카드 탭은 pendingAccessibilityRequestProvider를 쓰기와
  // 동시에 tabSwitchRequestProvider로 이 탭을 활성화시킨다. 이 두 provider
  // 갱신은 같은 동기 구간에서 일어나는데, 프로필 적용(ref.listen 콜백)이 먼저
  // 실행되고 그 다음 프레임에 MainShell이 리빌드되며 didUpdateWidget이 뒤늦게
  // 실행되므로, didUpdateWidget의 "탭 활성화 시 저장된 기본값으로 리셋" 로직이
  // 방금 적용한 카드의 대분류 필터를 덮어써 버린다. 이 플래그로 "지금 활성화는
  // 무장애 카드 요청 처리의 일부다"를 표시해 그 경우에만 리셋을 건너뛴다.
  bool _skipNextActivationReset = false;

  @override
  void initState() {
    super.initState();
    // 접근성 프로필/상세필드가 설정된 유저면 해당 대분류·필드를 기본
    // 활성화 상태로 보여주되, 이후에는 자유롭게 켜고 끌 수 있는 검색
    // 필터로 동작한다.
    _activeProfiles = _defaultActiveProfiles();
    _selectedFields = _defaultSelectedFields(_activeProfiles);

    // 홈 화면의 무장애 카드를 눌러 들어온 경우, 저장된 프로필 대신 그
    // 카드의 대분류만 활성화하고 상세 카테고리는 전체로 바로 검색한다.
    final pendingProfile = ref.read(pendingAccessibilityRequestProvider);
    if (pendingProfile != null) {
      _applyPendingAccessibilityRequest(pendingProfile);
    } else {
      // 저장된 관심 지역이 있으면 필터로 미리 채워둔다. 지역 코드를
      // AreaCode/SigunguCode 객체로 바꾸려면 area_codes.json을 읽어와야 해서
      // (AreaCodeRepository.load) 위 접근성 기본값과 달리 비동기로 처리한다.
      _applyDefaultRegion();
    }
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 탭으로 넘어가는 순간(=이 화면이 비활성화되는 순간)뿐 아니라 다시
    // 활성화되는 순간에도 검색 상태를 사용자의 저장된 접근성 프로필 기본값으로
    // 되돌린다. 화면 위젯 자체는 Offstage로 계속 살아있어서(MainShell), 비활성화
    // 시점에만 갱신하면 그 이후(예: 마이페이지에서 접근성 프로필을 수정하고 바로
    // 이 탭으로 돌아온 경우) 수정 전 값으로 캡처해둔 기본값이 그대로 남아있게
    // 된다 — 활성화 시점에도 다시 계산해서 항상 최신 저장값을 반영한다.
    if (oldWidget.isActive != widget.isActive) {
      if (_skipNextActivationReset) {
        _skipNextActivationReset = false;
      } else {
        _resetToDefaults();
      }
    }
  }

  /// 유저 계정에 저장된 접근성 대분류 목록.
  Set<AccessibilityProfile> _defaultActiveProfiles() {
    final user = ref.read(authStateProvider).user;
    final savedProfileNames = user?.accessibilityProfiles ?? const [];
    return AccessibilityProfile.values
        .where((profile) => savedProfileNames.contains(profile.name))
        .toSet();
  }

  /// [profiles] 각각에 대해 유저 계정에 저장된 상세 필드 목록.
  Map<AccessibilityProfile, Set<AccessibilityField>> _defaultSelectedFields(
    Set<AccessibilityProfile> profiles,
  ) {
    final user = ref.read(authStateProvider).user;
    final savedFieldsByProfile = user?.accessibilityFieldsByProfile ?? const {};
    return {
      for (final profile in profiles)
        if (savedFieldsByProfile[profile.name] case final savedFields?)
          profile: savedFields
              .map(_fieldFromName)
              .whereType<AccessibilityField>()
              .toSet(),
    };
  }

  /// 검색어/지역/카테고리/검색결과를 전부 지우고, 접근성 필터만 유저의
  /// 저장된 프로필 기본값으로 되돌린다(=처음 이 화면에 들어왔을 때와 동일).
  void _resetToDefaults() {
    final defaultProfiles = _defaultActiveProfiles();
    setState(() {
      _activeProfiles = defaultProfiles;
      _selectedFields = _defaultSelectedFields(defaultProfiles);
      _selectedSido = null;
      _selectedSigungus = {};
      _selectedCategories = {};
      _currentBatch = const [];
      _loadedBatchNumber = 0;
      _totalCount = 0;
      _currentPage = 1;
      _hasSearched = false;
      _isLoading = false;
    });
    _searchController.clear();
    _applyDefaultRegion();
  }

  /// 유저 계정에 저장된 관심 지역(시/도+시/군구)을 필터로 미리 채워둔다.
  /// area_codes.json을 읽어야 해서 비동기다 — 완료되기 전까지는 지역 필터가
  /// 비어 보이다가 잠시 뒤 채워진다(ExploreFilterScreen의 지역 탭 로딩과
  /// 같은 성격의 지연).
  Future<void> _applyDefaultRegion() async {
    final user = ref.read(authStateProvider).user;
    final sidoCode = user?.interestSidoCode;
    if (sidoCode == null) return;

    final areaCodes = await AreaCodeRepository.load();
    if (!mounted) return;

    AreaCode? sido;
    for (final area in areaCodes) {
      if (area.code == sidoCode) {
        sido = area;
        break;
      }
    }
    if (sido == null) return;

    final savedSigunguCodes = user?.interestSigunguCodes ?? const [];
    final sigungus = sido.sigungu
        .where((sg) => savedSigunguCodes.contains(sg.code))
        .toSet();

    setState(() {
      _selectedSido = sido;
      _selectedSigungus = sigungus;
    });
  }

  /// 지역/카테고리/검색어 등 기존 필터를 전부 지운 뒤 [profile] 대분류만
  /// 켜고 상세 카테고리는 "전체"(빈 Set)로 맞춰 바로 검색을 실행한다.
  void _applyPendingAccessibilityRequest(AccessibilityProfile profile) {
    _selectedSido = null;
    _selectedSigungus = {};
    _selectedCategories = {};
    _activeProfiles = {profile};
    _selectedFields = {profile: {}};
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pendingAccessibilityRequestProvider.notifier).state = null;
      _handleSearch();
    });
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
  // "검색하기"를 눌렀을 때(_handleSearch)만 실행한다
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
          initialSigungus: _selectedSigungus,
          initialCategories: _selectedCategories,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _selectedFields = result.selectedFields;
      _selectedSido = result.sido;
      _selectedSigungus = result.sigungus;
      _selectedCategories = result.categories;
    });
  }

  /// 무장애정보 상세필드/지역/카테고리 칩 목록
  /// 각 칩의 x를 누르면 해당 조건만 해제한다.
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
              _selectedSigungus = {};
            });
          },
        ),
      );
    }

    for (final sigungu in _selectedSigungus) {
      chips.add(
        _ActiveFilterChip(
          label: sigungu.name,
          onRemove: () {
            setState(() => _selectedSigungus.remove(sigungu));
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
      sigunguMemberCodes: _selectedSigungus.isEmpty
          ? null
          : _selectedSigungus.expand((sg) => sg.memberCodes).toList(),
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

    AppLogger.debug(
      '[Explore] 검색 keyword="${_searchController.text.trim()}" '
      'region=${_selectedSido?.code} '
      'sigungu=${_selectedSigungus.map((sg) => sg.name).toList()} '
      'categories=${_selectedCategories.map((c) => c.label).toList()} '
      'acceptableFields=$_acceptableFieldNames',
    );
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
    // 탐색 탭은 한 번 방문하면 Offstage로 숨겨질 뿐 다시 initState가 돌지
    // 않으므로(MainShell의 탭 유지 방식), 이미 떠 있는 상태에서 다른 무장애
    // 카드를 다시 눌렀을 때도 여기서 감지해 대분류를 갈아끼운다.
    ref.listen<AccessibilityProfile?>(pendingAccessibilityRequestProvider, (
      _,
      profile,
    ) {
      if (profile == null) return;
      _skipNextActivationReset = true;
      setState(() {
        _selectedSido = null;
        _selectedSigungus = {};
        _selectedCategories = {};
        _activeProfiles = {profile};
        _selectedFields = {profile: {}};
      });
      _searchController.clear();
      ref.read(pendingAccessibilityRequestProvider.notifier).state = null;
      _handleSearch();
    });

    return Stack(
      children: [
        Positioned.fill(child: _buildScrollableContent()),
        Positioned(
          right: 20.w,
          bottom: 20.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScrollFab(
                icon: Icons.north,
                semanticLabel: '맨 위로 이동',
                onTap: _scrollToTop,
              ),
              SizedBox(height: 11.h),
              ScrollFab(
                icon: Icons.south,
                semanticLabel: '맨 아래로 이동',
                onTap: _scrollToBottom,
              ),
            ],
          ),
        ),
        if (_isLoading) const Positioned.fill(child: LoadingOverlay()),
      ],
    );
  }

  /// 검색어~검색하기 버튼까지, 결과 유무와 무관하게 항상 보이는 상단 콘텐츠.
  List<Widget> _topContent() {
    return [
      Text(
        '맞춤 여행지 탐색',
        style: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      SizedBox(height: 22.h),
      _SearchBar(
        controller: _searchController,
        onSubmitted: (_) => _handleSearch(),
      ),
      SizedBox(height: 22.h),
      _AccessibilityProfileRow(
        activeProfiles: _activeProfiles,
        onToggle: _toggleProfile,
      ),
      SizedBox(height: 15.h),
      _FilterSelectRow(onTap: _openFilterScreen),
      SizedBox(height: 4.h),
      Text(
        '편의 정보와 지역, 카테고리를 선택할 수 있어요.',
        style: TextStyle(fontSize: 10.sp, color: AppColors.textTertiary),
      ),
      if (_activeFilterChips.isNotEmpty) ...[
        SizedBox(height: 10.h),
        _ActiveFilterChipsRow(chips: _activeFilterChips),
      ],
      SizedBox(height: 33.h),
      SizedBox(
        width: double.infinity,
        height: 47.h,
        child: ElevatedButton(
          onPressed: _handleSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.7.r),
            ),
          ),
          child: Text(
            '검색하기',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ];
  }

  Widget _buildScrollableContent() {
    if (!_hasSearched || _totalCount == 0) {
      return LayoutBuilder(
        builder: (context, viewportConstraints) {
          final verticalPadding = 24.h + 36.h;
          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 36.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight - verticalPadding,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._topContent(),
                    SizedBox(height: 24.h),
                    Expanded(
                      child: _hasSearched && !_isLoading
                          ? const Center(child: _EmptyResultState())
                          : const SizedBox.shrink(),
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
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 36.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._topContent(),
          SizedBox(height: 24.h),
          Semantics(
            liveRegion: true,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
                children: [
                  const TextSpan(text: '검색 결과 '),
                  TextSpan(
                    text: '$_totalCount건',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              strutStyle: StrutStyle(
                fontSize: 14.sp,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          _ResultGrid(items: _pageItems),
          SizedBox(height: 24.h),
          _PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageSelected: _goToPage,
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
      spacing: 8.w,
      runSpacing: 8.h,
      children: chips.map((chip) => _buildChip(chip)).toList(),
    );
  }

  Widget _buildChip(_ActiveFilterChip chip) {
    return Container(
      padding: EdgeInsets.only(left: 6.w, right: 10.w, top: 4.h, bottom: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFF),
        border: Border.all(color: const Color(0xFF989898), width: 0.5),
        borderRadius: BorderRadius.circular(5.5.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${chip.label} 필터 해제',
            button: true,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: chip.onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(
                  Icons.close,
                  size: 11.r,
                  color: AppColors.toggleUnselected,
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Text(
            chip.label,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
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
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 19.w),
      decoration: BoxDecoration(
        color: AppColors.searchBarBackground,
        borderRadius: BorderRadius.circular(34.r),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 24.r, color: AppColors.toggleUnselected),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: '검색',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slateGray,
                ),
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
    final labelFontSize = _profileLabelFontSize(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _kProfileOrder.length; i++) ...[
            if (i > 0) SizedBox(width: 21.4.w),
            _buildIcon(
              _kProfileOrder[i],
              activeProfiles.contains(_kProfileOrder[i]),
              labelFontSize,
            ),
          ],
        ],
      ),
    );
  }

  double _profileLabelFontSize(BuildContext context) {
    const designFontSize = 13.0;
    final baseFontSize = designFontSize.sp;
    final availableWidth = 48.w;
    final textScaler = MediaQuery.textScalerOf(context);

    var maxWidth = 0.0;
    for (final profile in _kProfileOrder) {
      final firstLine = profile.label.split(' ').first;
      final painter = TextPainter(
        text: TextSpan(
          text: firstLine,
          style: TextStyle(fontSize: baseFontSize, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }

    if (maxWidth <= availableWidth) return baseFontSize;
    return baseFontSize * (availableWidth / maxWidth);
  }

  Widget _buildIcon(
    AccessibilityProfile profile,
    bool isActive,
    double labelFontSize,
  ) {
    return Semantics(
      label: '${profile.label} 조건',
      button: true,
      selected: isActive,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onToggle(profile),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48.w,
          child: Column(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.toggleUnselectedBackground,
                ),
                child: Icon(
                  profile.icon,
                  size: 30.w,
                  color: isActive ? Colors.white : AppColors.toggleUnselected,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                profile.label.replaceFirst(' ', '\n'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
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
    return Semantics(
      label: '필터 선택, 편의 정보·지역·카테고리 선택',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '필터 선택',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.tune, size: 18.r, color: AppColors.navIconInactive),
          ],
        ),
      ),
    );
  }
}

class _EmptyResultState extends StatelessWidget {
  const _EmptyResultState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/explore/empty_search.png',
            width: 60.r,
            height: 60.r,
          ),
          SizedBox(height: 16.h),
          Text(
            '조건에 맞는 여행지가 없습니다.',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textQuaternary,
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
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20.h,
        crossAxisSpacing: 16.w,
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
    return Semantics(
      label: '${spot.title}, ${spot.addr1}',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
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
                borderRadius: BorderRadius.circular(12.r),
                child: spot.firstImage == null
                    ? _buildImagePlaceholder()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final cacheW = cacheDimension(
                            constraints.maxWidth,
                            dpr,
                          );
                          final cacheH = cacheDimension(
                            constraints.maxHeight,
                            dpr,
                          );
                          return CachedNetworkImage(
                            imageUrl: spot.firstImage!,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            // 관광공사 제공 사진 우하단에 로고가 찍혀있는 경우가
                            // 많아서, 크롭이 생기더라도 그 모서리는 항상
                            // 보존되도록 우하단 기준으로 자른다.
                            alignment: Alignment.bottomRight,
                            memCacheWidth: cacheW,
                            memCacheHeight: cacheH,
                            maxWidthDiskCache: cacheW,
                            maxHeightDiskCache: cacheH,
                            errorWidget: (context, url, error) =>
                                _buildImagePlaceholder(),
                            placeholder: (context, url) =>
                                _buildImagePlaceholder(loading: true),
                          );
                        },
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              spot.title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              spot.addr1,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (spot.supportedProfiles.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Row(
                children: _kProfileOrder
                    .where((p) => spot.supportedProfiles.contains(p))
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: Icon(
                          p.icon,
                          size: 14.r,
                          color: AppColors.toggleUnselected,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({bool loading = false}) {
    if (loading) {
      return Container(
        color: AppColors.inactiveSurface,
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
          leadingIcon: Icons.arrow_back_ios,
          enabled: currentPage > 1,
          onTap: () => onPageSelected(currentPage - 1),
        ),
        SizedBox(width: 8.w),
        ..._visiblePages.map(
          (page) => Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: _PageNumberButton(
              page: page,
              isSelected: page == currentPage,
              onTap: () => onPageSelected(page),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        _NavTextButton(
          label: '다음',
          trailingIcon: Icons.arrow_forward_ios,
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
    return Semantics(
      label: '$page페이지',
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: AppColors.textPrimary, width: 1),
                  )
                : null,
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
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
    final color = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    return Semantics(
      label: '$label 페이지',
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            if (leadingIcon != null)
              Transform.translate(
                offset: Offset(2.r, 0),
                child: Icon(leadingIcon, size: 14.r, color: color),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, size: 14.r, color: color),
          ],
        ),
      ),
    );
  }
}
