import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../model/accessibility/accessibility_field.dart';
import '../../model/tour/tour_category.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/location/location_service.dart';
import '../../services/region/area_code_repository.dart';
import '../../services/region/kakao_local_service.dart';
import '../../services/tour/tour_spot_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/accessibility_fit_level.dart';
import '../../utils/app_logger.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/toast.dart';
import '../auth/login_screen.dart';
import '../bookmark/save_to_folder_sheet.dart';
import 'spot_detail_screen.dart';

/// 위치 권한 거부/조회 실패 시 쓰는 기본 위치(서울시청)와 그 지역코드.
const _kDefaultCenter = LatLng(37.5665, 126.9780);
const _kFallbackRegionCode = '11';
const _kDefaultZoomLevel = 15;

/// 결과 지도에 한 번에 찍을 마커 상한. 지역 전체를 다 받아온 뒤 거리순으로
/// 자르므로, 마커가 너무 많아 렌더링/터치가 버벅이지 않게 상한을 둔다.
const _kMaxMarkers = 20;

/// 활성/비활성 핀 크기. 이미지 자체는 실제 검색결과 화면(831:763 등)에서 쓰인
/// 원본 컴포넌트인 피그마 노드 643:222(Group 147, 활성)/643:221(Group 146, 비활성)를
/// 그대로 내려받은 asset(assets/images/map_pin_active.png·map_pin_inactive.png).
/// (643:224/226은 이름만 비슷한 별도 초안 도형이라 실제로 쓰이는 노드가 아니었음.)
const _kActivePinSize = 32.0;
const _kInactivePinSize = 16.0;
const _kMyLocationDotSize = 20.0;

/// 상단 검색창 영역 배경 밴드 높이. 검색 전(카테고리 탭까지 보임, 피그마
/// 831:737)과 검색 후(카테고리 탭이 사라지고 검색창만 남는 831:763/1058)의
/// 높이가 다르다.
const _kTopBandHeightIdle = 117.0;
const _kTopBandHeightResults = 80.0;

/// 바텀시트 카드 한 줄의 고정 높이. ListView가 이 간격으로 딱 맞춰 스크롤해야
/// "지금 스크롤 offset ÷ 카드 높이"만으로 맨 위에 온 카드 index를 바로
/// 계산할 수 있다(카카오맵 자체 장소 리스트가 이렇게 동작한다).
const _kCardExtent = 214.0;
const _kSheetHeightFraction = 0.45;
// 시트를 아래로 내렸을 때 남는 최소 높이(필터 pill 줄 정도만 보이는 선) —
// 다시 위로 끌어올릴 수 있는 손잡이 역할을 한다.
const _kSheetMinHeightFraction = 0.16;

/// 무장애 정보 칩은 카드 한 줄에 다 담기 어려우니 최대 5개까지만 보여준다
/// (피그마 831:763 등 결과 카드가 항상 칩 5개짜리 슬롯으로 그려져 있음).
const _kMaxFacilityChips = 5;

enum _SortOption { distance, accuracy, bookmarkCount }

extension on _SortOption {
  String get label => switch (this) {
    _SortOption.distance => '거리순',
    _SortOption.accuracy => '정확도순',
    _SortOption.bookmarkCount => '저장목록순',
  };
}

/// 바텀시트의 카테고리/정렬/적합레벨 중 지금 펼쳐져 있는 게 무엇인지
/// (피그마 831:846/908/981 — 탭 하나만 눌러도 그 아래 선택지 줄이 펼쳐지는
/// 아코디언 형태라 팝업 메뉴가 아니다).
enum _FilterKind { category, sort, level }

/// 지도 기반 탐색 화면.
///
/// 검색 결과는 tourSpots 컬렉션 중 mapX/mapY(좌표)가 있는 장소만 대상으로 하며,
/// "내 위치가 속한 시/도" 전체를 서버에서 받아온 뒤 키워드/카테고리/거리는
/// 클라이언트에서 거른다 (explore_screen과 같은 지역기반 fetch + 클라이언트
/// 필터링 패턴, home_screen.dart의 위치→지역코드 변환 로직 재사용).
///
/// 진입 시에는 검색을 하지 않고 내 위치 마커만 보여주다가, 검색어를 입력하거나
/// 카테고리를 선택하면 그때부터 결과를 지도 마커+하단 바텀시트 목록으로 보여준다.
/// 바텀시트를 스크롤해 맨 위에 온 카드가 활성 상태(큰 핀)가 되고, 지도 마커를
/// 직접 탭하면 반대로 그 카드가 리스트 맨 위로 스크롤된다. 활성 스팟이 바뀌면
/// (스크롤로든 마커 탭으로든) 카메라도 그 위치로 따라간다.
///
/// 검색 결과가 떠 있는 동안에는 "이 장소 재검색" 버튼으로, 원래 GPS 위치가
/// 아니라 사용자가 지도를 움직여 지금 보고 있는 위치 기준으로 다시 검색할 수
/// 있다(카카오맵 등 지도 앱의 "이 지역 검색" 패턴과 동일).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _locationService = LocationService();
  final _kakaoLocalService = KakaoLocalService();
  final _tourSpotService = TourSpotService();
  final _searchController = TextEditingController();
  // DraggableScrollableSheet가 매번 builder에서 내려주는 컨트롤러 — 시트가
  // 아예 닫혔다가(뒤로가기) 다시 열리면 새 인스턴스로 바뀌므로 field로 들고
  // 있다가 바뀔 때만 리스너를 다시 붙인다([_bindSheetScrollController]).
  ScrollController? _sheetScrollController;
  // 필터 pill 줄 영역을 손으로 끌 때(리스트가 아닌 고정 영역) 시트 크기를
  // 직접 조작하기 위한 컨트롤러.
  final _sheetController = DraggableScrollableController();

  late final Future<Position?> _initialPositionFuture;

  KakaoMapController? _mapController;
  final List<Poi> _resultMarkers = [];
  final List<PoiStyle> _smallStyles = [];
  final List<PoiStyle> _bigStyles = [];
  Poi? _myLocationMarker;

  TourCategory? _selectedCategory;
  _SortOption _sortOption = _SortOption.distance;
  AccessibilityFitLevel? _minFitLevel;
  _FilterKind? _expandedFilter;
  bool _showInfoTooltip = false;
  String? _regionCode;
  bool _hasSearched = false;
  bool _isLoading = false;
  // 지도가 뜨자마자 기본값(서울시청)으로 그려졌다가 실제 GPS 위치로
  // 넘어가는 게 눈에 보이면 혼선이 생기므로, 카메라가 진짜 위치로 옮겨질
  // 때까지는 이 화면을 로딩으로 가리고 있다가 한 번에 보여준다.
  bool _isLocating = true;
  // _handleMarkerTap이 리스트를 활성 카드로 스크롤시킬 때, 그 스크롤 자체가
  // 다시 스크롤 리스너를 건드려 활성 인덱스를 재계산하지 않도록 막는 플래그.
  bool _isProgrammaticScroll = false;
  LatLng _currentPosition = _kDefaultCenter;

  List<TourSpot> _results = const [];
  int _activeIndex = 0;
  // DraggableScrollableSheet가 지금 차지하고 있는 화면 높이 비율. 내 위치
  // 버튼을 시트 바로 위에 붙이려면 드래그로 계속 바뀌는 이 값을 알아야 한다.
  double _sheetExtent = _kSheetHeightFraction;

  @override
  void initState() {
    super.initState();
    // 지도 플랫폼 뷰가 만들어지는 동안(onMapReady 호출 전) GPS 조회를 병렬로
    // 미리 시작해서, 지도가 뜨자마자 바로 카메라를 옮길 수 있게 한다.
    _initialPositionFuture = _locationService.getCurrentPosition();
  }

  @override
  void dispose() {
    // 이 화면을 벗어날 때 하단 탭 바 숨김 상태가 다른 탭에 남지 않게 되돌린다.
    ref.read(mapResultsActiveProvider.notifier).state = false;
    _searchController.dispose();
    // DraggableScrollableSheet가 자기가 만든 scrollController는 알아서
    // dispose하므로 여기서는 리스너만 떼어낸다.
    _sheetScrollController?.removeListener(_handleListScroll);
    _sheetController.dispose();
    super.dispose();
  }

  /// DraggableScrollableSheet의 builder는 시트가 새로 열릴 때마다(뒤로가기로
  /// 닫혔다가 마커 탭으로 재오픈 등) 새 ScrollController를 내려줄 수 있어서,
  /// 리스너가 옛 컨트롤러에 남아있지 않도록 바뀔 때만 갈아 끼운다.
  void _bindSheetScrollController(ScrollController controller) {
    if (identical(_sheetScrollController, controller)) return;
    _sheetScrollController?.removeListener(_handleListScroll);
    _sheetScrollController = controller;
    controller.addListener(_handleListScroll);
  }

  Future<void> _handleMapReady(KakaoMapController controller) async {
    _mapController = controller;

    final position = await _initialPositionFuture;
    final latLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : _kDefaultCenter;

    if (!mounted) return;
    setState(() => _currentPosition = latLng);

    await controller.moveCamera(
      CameraUpdate.newCenterPosition(latLng, zoomLevel: _kDefaultZoomLevel),
    );
    await _updateMyLocationMarker(latLng);
    if (mounted) setState(() => _isLocating = false);

    // 지역코드는 검색 시점에 바로 쓸 수 있게 미리 구해두지만, 실제 검색/마커
    // 렌더링은 사용자가 검색어를 입력하거나 카테고리를 선택했을 때부터 시작한다
    // — 진입 직후에는 지도에 내 위치만 보여야 한다.
    _regionCode = position != null
        ? await _resolveRegionCode(latLng) ?? _kFallbackRegionCode
        : _kFallbackRegionCode;
  }

  /// GPS 좌표 → 카카오 역지오코딩 → area_codes.json 매칭까지, home_screen.dart의
  /// 위치 기반 지역 판별과 같은 규칙(시/도 접미사 제거, 광주·전남 통합코드 예외)을 쓴다.
  Future<String?> _resolveRegionCode(LatLng position) async {
    final region = await _kakaoLocalService.reverseGeocodeDistrict(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (region == null) return null;

    final areaCodes = await AreaCodeRepository.load();
    final bySidoName = <String, String>{
      for (final area in areaCodes) _normalizeSidoName(area.name): area.code,
    };
    // area_codes.json의 code "12"는 광주광역시+전라남도를 합쳐 담고 있어서,
    // 접미사 제거 정규화만으로는 카카오가 내려주는 "광주광역시"/"전라남도"와 안 걸린다.
    bySidoName['광주'] = '12';
    bySidoName['전라남'] = '12';

    return bySidoName[_normalizeSidoName(region.sido)];
  }

  String _normalizeSidoName(String name) =>
      name.replaceAll(RegExp(r'(특별자치시|특별자치도|광역시|특별시|도)$'), '');

  double _distanceOf(TourSpot spot) =>
      LatLng(spot.mapY!, spot.mapX!).distance(_currentPosition);

  /// "정확도순"은 검색어와 제목이 얼마나 가깝게 일치하는지로 줄을 세운다 —
  /// 제목 안에서 검색어가 더 앞쪽에 나올수록 관련도가 높다고 본다. 검색어가
  /// 없으면 기준으로 삼을 신호가 없어 거리순과 동률로 취급한다.
  int _accuracyRank(TourSpot spot, String keyword) {
    if (keyword.isEmpty) return 0;
    final index = spot.title.toLowerCase().indexOf(keyword);
    return index < 0 ? 1 << 20 : index;
  }

  /// GPS로 잡은 최초 위치가 아니라, 사용자가 지도를 움직여 지금 실제로 보고
  /// 있는 위치를 기준으로 거리 정렬·지역을 다시 계산해둔다. [_runSearch]가
  /// 검색어 제출/카테고리·정렬·적합레벨 선택/"이 장소 재검색" 등 모든 검색
  /// 진입점에서 매번 먼저 호출해서, 지도를 옮겨둔 채로 무엇을 하든 항상 그
  /// 위치 기준으로 검색되게 한다.
  Future<void> _syncPositionFromCamera() async {
    final controller = _mapController;
    if (controller == null) return;

    final cameraPosition = await controller.getCameraPosition();
    final latLng = cameraPosition.position;
    if (!mounted) return;
    setState(() => _currentPosition = latLng);
    _regionCode =
        await _resolveRegionCode(latLng) ?? _regionCode ?? _kFallbackRegionCode;
  }

  /// "이 장소 재검색" 버튼.
  Future<void> _handleResearchThisArea() => _runSearch();

  /// 검색어 제출/카테고리·정렬·적합레벨 선택 시 즉시 호출된다. 지역 전체를
  /// 받아 좌표 있는 장소만 남기고, 키워드(제목 부분일치)·카테고리·최소
  /// 적합레벨로 거른 뒤 선택한 기준으로 정렬해 상위 [_kMaxMarkers]건만
  /// 마커+바텀시트 목록으로 그린다.
  Future<void> _runSearch() async {
    await _syncPositionFromCamera();
    final regionCode = _regionCode;
    if (regionCode == null) return;

    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });

    final spots = await _tourSpotService.searchByRegion(regionCode);
    final keyword = _searchController.text.trim().toLowerCase();
    final category = _selectedCategory;
    final minLevel = _minFitLevel;
    final selectedFields = resolveSelectedFields(
      ref.read(authStateProvider).user,
    );

    final filtered = spots.where((spot) {
      if (spot.mapX == null || spot.mapY == null) return false;
      if (keyword.isNotEmpty && !spot.title.toLowerCase().contains(keyword)) {
        return false;
      }
      if (category != null && spot.contentTypeId != category.contentTypeId) {
        return false;
      }
      if (minLevel != null) {
        final fit = calculateAccessibilityFit(
          selectedFields: selectedFields,
          populatedFields: spot.populatedFields,
        );
        // 적합레벨이 아예 산정 안 되는(비회원/프로필 미설정) 상태거나 기준
        // 레벨에 못 미치면 "Lv.N 이상" 필터를 통과하지 못한 것으로 본다.
        if (fit.level == null || fit.level!.index < minLevel.index) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.distance:
          return _distanceOf(a).compareTo(_distanceOf(b));
        case _SortOption.bookmarkCount:
          final byCount = b.bookmarkCount.compareTo(a.bookmarkCount);
          return byCount != 0
              ? byCount
              : _distanceOf(a).compareTo(_distanceOf(b));
        case _SortOption.accuracy:
          final byAccuracy = _accuracyRank(
            a,
            keyword,
          ).compareTo(_accuracyRank(b, keyword));
          return byAccuracy != 0
              ? byAccuracy
              : _distanceOf(a).compareTo(_distanceOf(b));
      }
    });

    final nearest = filtered.take(_kMaxMarkers).toList();

    AppLogger.debug(
      '[Map] 검색 region=$regionCode keyword="$keyword" '
      'category=${category?.label} sort=${_sortOption.label} '
      'minLevel=${minLevel?.label} 결과=${filtered.length}건 '
      '(마커=${nearest.length}건)',
    );

    await _renderResultMarkers(nearest);

    if (!mounted) return;
    setState(() {
      _results = nearest;
      _activeIndex = 0;
      _isLoading = false;
    });
    if (_sheetScrollController?.hasClients ?? false) {
      _sheetScrollController!.jumpTo(0);
    }
    // 검색/카테고리 선택 직후에는 목록 맨 위(활성) 여행지가 화면 중앙에
    // 오도록 카메라도 같이 옮긴다 — 카카오맵 장소 리스트와 동일한 동작.
    if (nearest.isNotEmpty) await _focusCameraOn(0);
  }

  Future<void> _renderResultMarkers(List<TourSpot> spots) async {
    final controller = _mapController;
    if (controller == null) return;

    for (final marker in _resultMarkers) {
      await controller.labelLayer.removePoi(marker);
    }
    _resultMarkers.clear();
    _smallStyles.clear();
    _bigStyles.clear();

    final smallIcon = KImage.fromAsset(
      'assets/images/map_pin_inactive.png',
      _kInactivePinSize.toInt(),
      _kInactivePinSize.toInt(),
    );
    final bigIcon = KImage.fromAsset(
      'assets/images/map_pin_active.png',
      _kActivePinSize.toInt(),
      _kActivePinSize.toInt(),
    );
    final smallStyle = PoiStyle(icon: smallIcon);
    final bigStyle = PoiStyle(icon: bigIcon);

    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      _smallStyles.add(smallStyle);
      _bigStyles.add(bigStyle);

      final poi = await controller.labelLayer.addPoi(
        LatLng(spot.mapY!, spot.mapX!),
        style: i == 0 ? bigStyle : smallStyle,
        onClick: () => _handleMarkerTap(i),
      );
      _resultMarkers.add(poi);
    }
  }

  /// 마커 스타일(작은 핀 ↔ 큰 핀)만 바꾼다. 카메라나 리스트 스크롤 위치는
  /// 건드리지 않는다 — 호출부(스크롤/탭)에서 필요한 만큼만 따로 더 처리한다.
  Future<void> _syncActiveMarkerStyle(int previous, int next) async {
    if (previous != next && previous < _resultMarkers.length) {
      await _resultMarkers[previous].changeStyles(_smallStyles[previous]);
    }
    if (next < _resultMarkers.length) {
      await _resultMarkers[next].changeStyles(_bigStyles[next]);
    }
  }

  /// 활성 스팟이 바뀔 때마다 카메라를 그 위치로 옮겨 항상 화면 중앙에 오게
  /// 한다 — 카카오맵 자체 장소 리스트가 스크롤/탭 둘 다에서 이렇게 동작한다.
  Future<void> _focusCameraOn(int index) async {
    if (index < 0 || index >= _results.length) return;
    final spot = _results[index];
    await _mapController?.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(spot.mapY!, spot.mapX!)),
      animation: const CameraAnimation(250),
    );
  }

  /// 바텀시트를 스크롤해서 활성 카드가 바뀔 때마다 호출된다. 카드 높이가
  /// 고정([_kCardExtent])이라 스크롤 offset을 나눈 몫이 곧 지금 활성 카드
  /// index다. floor 대신 round를 써서, 카드 하나를 완전히 다 넘겨야(줄에
  /// 딱 맞아야) 바뀌는 게 아니라 절반쯤 스크롤한 시점에 다음 카드로 넘어가게
  /// 한다.
  void _handleListScroll() {
    final controller = _sheetScrollController;
    if (_isProgrammaticScroll || _results.isEmpty || controller == null) {
      return;
    }
    final index = (controller.offset / _kCardExtent.h).round().clamp(
      0,
      _results.length - 1,
    );
    if (index == _activeIndex) return;

    final previous = _activeIndex;
    setState(() => _activeIndex = index);
    _syncActiveMarkerStyle(previous, index);
    _focusCameraOn(index);
  }

  /// 지도 마커를 직접 탭했을 때: 그 장소를 활성화하고 카메라를 옮긴 뒤,
  /// 리스트도 그 카드가 맨 위로 오도록 스크롤한다(카카오맵 장소 리스트와 동일 동작).
  /// 뒤로가기로 시트를 닫은 뒤에도 마커는 지도에 그대로 남아있으니, 그 상태에서
  /// 마커를 탭하면 시트를 다시 띄운다.
  Future<void> _handleMarkerTap(int index) async {
    if (index < 0 || index >= _results.length) return;

    final previous = _activeIndex;
    final reopening = !_hasSearched;
    setState(() {
      _activeIndex = index;
      _hasSearched = true;
      if (reopening) _sheetExtent = _kSheetHeightFraction;
    });
    if (previous != index) await _syncActiveMarkerStyle(previous, index);
    await _focusCameraOn(index);

    if (reopening) {
      // 시트가 이번 탭으로 새로 열렸다면 DraggableScrollableSheet가 다음
      // 프레임에야 scrollController를 내려준다.
      await WidgetsBinding.instance.endOfFrame;
    }
    final controller = _sheetScrollController;
    if (controller != null && controller.hasClients) {
      _isProgrammaticScroll = true;
      await controller.animateTo(
        index * _kCardExtent.h,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _isProgrammaticScroll = false;
    }
  }

  Future<void> _updateMyLocationMarker(LatLng position) async {
    final controller = _mapController;
    if (controller == null) return;

    if (_myLocationMarker != null) {
      await controller.labelLayer.removePoi(_myLocationMarker!);
      _myLocationMarker = null;
    }
    final icon = await KImage.fromWidget(
      const _MyLocationDot(),
      const Size(_kMyLocationDotSize, _kMyLocationDotSize),
    );
    _myLocationMarker = await controller.labelLayer.addPoi(
      position,
      style: PoiStyle(icon: icon),
    );
  }

  Future<void> _handleMyLocationTap() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null || !mounted) return;

    final latLng = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = latLng);
    await _mapController?.moveCamera(
      CameraUpdate.newCenterPosition(latLng, zoomLevel: _kDefaultZoomLevel),
      animation: const CameraAnimation(300),
    );
    await _updateMyLocationMarker(latLng);
  }

  void _handleCategoryTap(TourCategory category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    _runSearch();
  }

  void _handleToggleFilter(_FilterKind kind) {
    setState(() => _expandedFilter = _expandedFilter == kind ? null : kind);
  }

  // 2차 옵션을 고른다고 필터 칸을 바로 접지 않는다 — 1차 필터 pill을 다시
  // 눌러 명시적으로 닫기 전까지는(검색/로딩이 도는 동안에도) 펼쳐진 상태를
  // 그대로 유지해야, 선택 전후로 헤더 높이가 갑자기 줄어들거나 로딩과 함께
  // 필터 칸이 닫히는 것처럼 보이지 않는다.
  void _handleCategoryOptionSelected(TourCategory? category) {
    setState(() => _selectedCategory = category);
    _runSearch();
  }

  void _handleSortOptionSelected(_SortOption option) {
    setState(() => _sortOption = option);
    _runSearch();
  }

  void _handleMinFitLevelOptionSelected(AccessibilityFitLevel? level) {
    setState(() => _minFitLevel = level);
    _runSearch();
  }

  void _handleInfoTap() {
    setState(() => _showInfoTooltip = !_showInfoTooltip);
  }

  @override
  Widget build(BuildContext context) {
    // 이 화면은 MainShell의 공용 TopLogoBanner를 안 쓰고(main_shell.dart 참고)
    // 자체 헤더 밴드가 화면 맨 위부터 시작하므로, 상태바 인셋은 배너가 해주던
    // 것처럼 여기서 직접 더해준다.
    final topInset = MediaQuery.paddingOf(context).top;
    final user = ref.watch(authStateProvider).user;
    final selectedFields = resolveSelectedFields(user);

    // MainShell의 하단 탭 바는 검색 결과 상태와 항상 같은 값을 봐야 하므로,
    // 매 빌드 뒤 프레임에서 동기화한다(빌드 도중 provider를 직접 수정하면 안 됨).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(mapResultsActiveProvider.notifier);
      if (notifier.state != _hasSearched) notifier.state = _hasSearched;
    });

    return PopScope(
      // 다른 바텀시트(showModalBottomSheet)는 자체 라우트를 갖고 있어서 뒤로가기가
      // 자동으로 그 라우트만 pop한다. 이 시트는 별도 라우트가 없는 Stack 위젯이라
      // 그대로 두면 뒤로가기가 화면(=앱)까지 pop해버리므로, 검색 결과/펼친 필터가
      // 있을 때는 그것부터 접고 화면 자체는 pop되지 않게 막는다.
      canPop: _expandedFilter == null && !_hasSearched,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_expandedFilter != null) {
            _expandedFilter = null;
          } else {
            _hasSearched = false;
            _showInfoTooltip = false;
          }
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sheetHeight = constraints.maxHeight * _sheetExtent;

          return Stack(
            children: [
              Positioned.fill(
                child: KakaoMap(
                  option: const KakaoMapOption(
                    position: _kDefaultCenter,
                    zoomLevel: _kDefaultZoomLevel,
                  ),
                  onMapReady: _handleMapReady,
                  // 기본(Virtual Display) 모드는 바텀시트 높이 변화 등으로 뷰가
                  // 리사이즈될 때 SurfaceProducer가 이미 해제된 상태에서 접근해
                  // NPE로 앱이 죽는 경우가 있었다(kakao_map_sdk 자체 문서에도
                  // 기본 모드가 상태관리 측면에서 문제가 있다고 명시되어 있음).
                  forceHybridComposition: true,
                ),
              ),
              // 검색창(+검색 전에는 카테고리 탭) 영역은 지도 위에 투명하게 뜨면
              // 안 되고, 피그마처럼 고정 배경(연한 파랑)이 깔린 하나의 헤더
              // 밴드여야 한다. 검색 결과가 뜨면(831:763/1058) 카테고리 탭은
              // 사라지고 밴드도 검색창 높이만큼만 남는다 — 카테고리 필터는
              // 바텀시트 안의 아코디언 드롭다운으로 옮겨간다.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height:
                      topInset +
                      (_hasSearched
                              ? _kTopBandHeightResults
                              : _kTopBandHeightIdle)
                          .h,
                  color: AppColors.background,
                ),
              ),
              Positioned(
                left: 16.5.w,
                top: topInset + 18.23.h,
                child: _SearchBar(
                  controller: _searchController,
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              if (!_hasSearched) ...[
                Positioned(
                  top: topInset + 68.23.h,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 0.5.h,
                    color: AppColors.hairlineDivider,
                  ),
                ),
                Positioned(
                  top: topInset + 78.23.h,
                  left: 0,
                  right: 0,
                  child: _CategoryChips(
                    selected: _selectedCategory,
                    onTap: _handleCategoryTap,
                  ),
                ),
              ],
              // 검색 결과가 떠 있는 동안, GPS 위치가 아니라 사용자가 지금
              // 움직여서 보고 있는 지도 영역 기준으로 다시 검색하는 버튼
              // (피그마 831:763/846/981/1058 전부에 항상 떠 있다).
              if (_hasSearched)
                Positioned(
                  top: topInset + 87.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ResearchAreaButton(onTap: _handleResearchThisArea),
                  ),
                ),
              Positioned(
                right: 16.w,
                bottom: _hasSearched ? sheetHeight + 16.h : 24.h,
                child: _MyLocationButton(onTap: _handleMyLocationTap),
              ),
              if (_hasSearched)
                Positioned.fill(
                  child: NotificationListener<DraggableScrollableNotification>(
                    // 시트를 내렸다 올렸다 할 때마다(드래그) 지금 차지하고
                    // 있는 높이 비율을 알아내서 내 위치 버튼 위치를 맞춘다.
                    onNotification: (notification) {
                      if ((notification.extent - _sheetExtent).abs() > 0.001) {
                        setState(() => _sheetExtent = notification.extent);
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: _kSheetHeightFraction,
                      minChildSize: _kSheetMinHeightFraction,
                      maxChildSize: _kSheetHeightFraction,
                      snap: true,
                      snapSizes: const [
                        _kSheetMinHeightFraction,
                        _kSheetHeightFraction,
                      ],
                      builder: (context, scrollController) {
                        _bindSheetScrollController(scrollController);
                        return _ResultSheet(
                          isLoading: _isLoading,
                          results: _results,
                          activeIndex: _activeIndex,
                          currentPosition: _currentPosition,
                          selectedFields: selectedFields,
                          scrollController: scrollController,
                          expandedFilter: _expandedFilter,
                          onToggleFilter: _handleToggleFilter,
                          selectedCategory: _selectedCategory,
                          onCategorySelected: _handleCategoryOptionSelected,
                          sortOption: _sortOption,
                          onSortSelected: _handleSortOptionSelected,
                          minFitLevel: _minFitLevel,
                          onMinFitLevelSelected:
                              _handleMinFitLevelOptionSelected,
                          showInfoTooltip: _showInfoTooltip,
                          onInfoTap: _handleInfoTap,
                          isGuest: user == null,
                          sheetController: _sheetController,
                          minChildSize: _kSheetMinHeightFraction,
                          maxChildSize: _kSheetHeightFraction,
                        );
                      },
                    ),
                  ),
                ),
              // login_loading_screen.dart와 같은 방식 — 전체 화면을 어둡게
              // 깔고 그 위에 로딩 애니메이션을 띄운다.
              if (_isLoading || _isLocating)
                const Positioned.fill(child: LoadingOverlay()),
            ],
          );
        },
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kMyLocationDotSize,
      height: _kMyLocationDotSize,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
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
      width: 328.w,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21.069.r),
        border: Border.all(color: AppColors.faintDivider, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 24.r, color: AppColors.navIconInactive),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: '장소, 주소 검색',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textQuaternary,
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

/// 카테고리 탭. tour_category.dart의 TourCategory.values 순서를 그대로 써서
/// 검색결과 화면의 카테고리 아코디언(_FilterSection)과 항목/순서가 항상 같게
/// 맞춘다. 한 화면에 다 못 담는 폭에서는 옆으로 스와이프해서 볼 수 있어야
/// 하므로 절대 좌표가 아니라 가로 스크롤되는 Row로 그리고, 칩 너비도 고정값
/// 대신 텍스트 길이에 맞춰 자연스럽게 정해지게 한다.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onTap});

  final TourCategory? selected;
  final ValueChanged<TourCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.5.w),
        child: Row(
          children: [
            for (final category in TourCategory.values) ...[
              _CategoryChip(
                label: category.label,
                selected: category == selected,
                onTap: () => onTap(category),
              ),
              SizedBox(width: 10.w),
            ],
          ],
        ),
      ),
    );
  }
}

/// 통합필터선택 화면(explore_filter_screen.dart)의 칩과 같은 방식 —
/// 배경을 채우지 않고 테두리/글자색만 바뀌는 것으로 선택 상태를 표현한다.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(53.13.r),
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : AppColors.chipInactiveBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(9.r),
          child: Icon(Icons.my_location, size: 22.r, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// "이 장소 재검색" 버튼(피그마 831:763/846/981/1058 공통 — 흰 알약 버튼 +
/// 새로고침 아이콘, 지도 상단 중앙).
class _ResearchAreaButton extends StatelessWidget {
  const _ResearchAreaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(53.13.r),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(53.13.r),
        child: Container(
          height: 36.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(53.13.r),
            border: Border.all(color: AppColors.boldDivider, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 16.r, color: AppColors.textSecondary),
              SizedBox(width: 4.w),
              Text(
                '이 장소 재검색',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지도 하단에 고정으로 얹히는 주변 여행지 목록 바텀시트. 배경/모서리는
/// save_to_folder_sheet.dart와 같은 톤(AppColors.bottomSheetBackground,
/// 위쪽만 둥근 모서리)을 따르되, 이 화면은 피그마(831:763 등)에 그림자값이
/// 따로 박혀있어 그 값을 그대로 쓴다.
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.isLoading,
    required this.results,
    required this.activeIndex,
    required this.currentPosition,
    required this.selectedFields,
    required this.scrollController,
    required this.expandedFilter,
    required this.onToggleFilter,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.sortOption,
    required this.onSortSelected,
    required this.minFitLevel,
    required this.onMinFitLevelSelected,
    required this.showInfoTooltip,
    required this.onInfoTap,
    required this.isGuest,
    required this.sheetController,
    required this.minChildSize,
    required this.maxChildSize,
  });

  final bool isLoading;
  final List<TourSpot> results;
  final int activeIndex;
  final LatLng currentPosition;
  final Set<AccessibilityField> selectedFields;
  final ScrollController scrollController;
  final _FilterKind? expandedFilter;
  final ValueChanged<_FilterKind> onToggleFilter;
  final TourCategory? selectedCategory;
  final ValueChanged<TourCategory?> onCategorySelected;
  final _SortOption sortOption;
  final ValueChanged<_SortOption> onSortSelected;
  final AccessibilityFitLevel? minFitLevel;
  final ValueChanged<AccessibilityFitLevel?> onMinFitLevelSelected;
  final bool showInfoTooltip;
  final VoidCallback onInfoTap;
  final bool isGuest;
  final DraggableScrollableController sheetController;
  final double minChildSize;
  final double maxChildSize;

  /// 카테고리/정렬/적합레벨 pill 줄 영역은 스크롤 목록이 아니라서, 그 위에서
  /// 손가락을 끌어도 DraggableScrollableSheet의 기본 드래그 제스처가 먹지
  /// 않는다(리스트를 잡고 내리는 것만 되던 이유). 이 영역을 직접 드래그하면
  /// sheetController로 시트 크기를 수동으로 따라가게 한다.
  void _handleHeaderDragUpdate(DragUpdateDetails details, double screenHeight) {
    final delta = details.primaryDelta ?? 0;
    if (screenHeight <= 0) return;
    final next = (sheetController.size - delta / screenHeight).clamp(
      minChildSize,
      maxChildSize,
    );
    sheetController.jumpTo(next);
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    final mid = (minChildSize + maxChildSize) / 2;
    final target = sheetController.size >= mid ? maxChildSize : minChildSize;
    sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bottomSheetBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(27.481.r),
          topRight: Radius.circular(27.481.r),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DB4B4B4),
            blurRadius: 3.664,
            offset: Offset(0, -1.832),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) => _handleHeaderDragUpdate(
                  details,
                  MediaQuery.sizeOf(context).height,
                ),
                onVerticalDragEnd: _handleHeaderDragEnd,
                child: Column(
                  children: [
                    SizedBox(height: 18.h),
                    _FilterSection(
                      expandedFilter: expandedFilter,
                      onToggleFilter: onToggleFilter,
                      selectedCategory: selectedCategory,
                      onCategorySelected: onCategorySelected,
                      sortOption: sortOption,
                      onSortSelected: onSortSelected,
                      minFitLevel: minFitLevel,
                      onMinFitLevelSelected: onMinFitLevelSelected,
                      onInfoTap: onInfoTap,
                    ),
                    // 필터가 펼쳐진 상태면 _FilterSection이 옵션 줄 아래
                    // 여백을 이미 만들어주므로, 여기서 또 더하지 않는다.
                    if (expandedFilter == null) SizedBox(height: 18.h),
                    Container(height: 0.5.h, color: AppColors.hairlineDivider),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.bottomSheetBackground,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
          if (showInfoTooltip)
            Positioned(
              top: 57.h,
              right: 20.w,
              child: _InfoTooltipBubble(isGuest: isGuest),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 로딩 중 표시는 전체 화면 LoadingAnimation 오버레이 하나로 통일한다 —
    // 여기서 또 CircularProgressIndicator를 띄우면 로딩 표시가 두 개
    // 겹쳐 보인다.
    if (results.isEmpty) {
      if (isLoading) return const SizedBox.shrink();
      return Center(
        child: Text(
          '주변에 조건에 맞는 여행지가 없어요',
          style: TextStyle(fontSize: 13.sp, color: AppColors.textQuaternary),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      // ListView는 padding을 안 주면 MediaQuery의 상단 인셋(상태바 높이)을
      // 리스트 맨 위에 자동으로 끼워넣는다(Flutter 기본 동작) — 그 빈
      // 공간이 활성 카드 배경색보다 위에 떠서 구분선과 첫 카드 사이에
      // 색이 다른 여백처럼 보였다.
      padding: EdgeInsets.zero,
      itemExtent: _kCardExtent.h,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final spot = results[index];
        return _SpotListCard(
          spot: spot,
          active: index == activeIndex,
          distanceMeters: LatLng(
            spot.mapY!,
            spot.mapX!,
          ).distance(currentPosition),
          selectedFields: selectedFields,
        );
      },
    );
  }
}

/// 정보 툴팁. 피그마 원본은 말풍선 모양 벡터(둥근 사각형 + 위쪽 꼬리)를 통째로
/// 이미지로 내보낸 것이라, Figma 내보내기 특유의 배경 투명도 문제(흰 배경이
/// 그대로 박혀 나옴)를 피하려고 같은 모양을 CustomPainter로 직접 그린다.
class _InfoTooltipBubble extends StatelessWidget {
  const _InfoTooltipBubble({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final tailHeight = 7.r;
    return CustomPaint(
      painter: _TooltipBubblePainter(
        tailHeight: tailHeight,
        tailWidth: 14.r,
        tailRightInset: 14.5.r,
        radius: 8.r,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 278.w),
        padding: EdgeInsets.fromLTRB(10.w, tailHeight + 8.h, 10.w, 8.h),
        child: Text(
          isGuest
              ? '사용자 조건이 설정되면 적합 레벨을 확인할 수 있어요.'
              : '선택한 접근성 조건과 잘 맞을수록 레벨이 높아져요.',
          style: TextStyle(fontSize: 11.sp, color: Colors.white),
        ),
      ),
    );
  }
}

class _TooltipBubblePainter extends CustomPainter {
  const _TooltipBubblePainter({
    required this.tailHeight,
    required this.tailWidth,
    required this.tailRightInset,
    required this.radius,
  });

  final double tailHeight;
  final double tailWidth;
  final double tailRightInset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, tailHeight, size.width, size.height - tailHeight),
      Radius.circular(radius),
    );
    final tailCenterX = size.width - tailRightInset;
    final path = Path()
      ..addRRect(rrect)
      ..moveTo(tailCenterX - tailWidth / 2, tailHeight)
      ..lineTo(tailCenterX, 0)
      ..lineTo(tailCenterX + tailWidth / 2, tailHeight)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.2), 4, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TooltipBubblePainter oldDelegate) =>
      oldDelegate.tailHeight != tailHeight ||
      oldDelegate.tailWidth != tailWidth ||
      oldDelegate.tailRightInset != tailRightInset ||
      oldDelegate.radius != radius;
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.expandedFilter,
    required this.onToggleFilter,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.sortOption,
    required this.onSortSelected,
    required this.minFitLevel,
    required this.onMinFitLevelSelected,
    required this.onInfoTap,
  });

  final _FilterKind? expandedFilter;
  final ValueChanged<_FilterKind> onToggleFilter;
  final TourCategory? selectedCategory;
  final ValueChanged<TourCategory?> onCategorySelected;
  final _SortOption sortOption;
  final ValueChanged<_SortOption> onSortSelected;
  final AccessibilityFitLevel? minFitLevel;
  final ValueChanged<AccessibilityFitLevel?> onMinFitLevelSelected;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              _FilterPill(
                label: '카테고리',
                isExpanded: expandedFilter == _FilterKind.category,
                onTap: () => onToggleFilter(_FilterKind.category),
              ),
              SizedBox(width: 8.w),
              _FilterPill(
                label: '정렬',
                isExpanded: expandedFilter == _FilterKind.sort,
                onTap: () => onToggleFilter(_FilterKind.sort),
              ),
              SizedBox(width: 8.w),
              _FilterPill(
                label: '적합레벨',
                isExpanded: expandedFilter == _FilterKind.level,
                onTap: () => onToggleFilter(_FilterKind.level),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.info_outline,
                  size: 29.r,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        // 옵션 칩 줄 위/아래 여백을 같은 값(8h)으로 둬서 그 칸 안에서
        // 위나 아래로 쏠리지 않고 가운데에 오게 한다.
        if (expandedFilter != null) ...[
          SizedBox(height: 12.h),
          Container(height: 0.5.h, color: AppColors.hairlineDivider),
          SizedBox(height: 8.h),
        ],
        if (expandedFilter == _FilterKind.category)
          SizedBox(
            height: 27.481.h,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  for (var i = 0; i < TourCategory.values.length; i++) ...[
                    if (i > 0) SizedBox(width: 8.w),
                    _OptionPill(
                      label: TourCategory.values[i].label,
                      selected: selectedCategory == TourCategory.values[i],
                      onTap: () => onCategorySelected(
                        selectedCategory == TourCategory.values[i]
                            ? null
                            : TourCategory.values[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (expandedFilter == _FilterKind.sort)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                for (var i = 0; i < _SortOption.values.length; i++) ...[
                  if (i > 0) SizedBox(width: 8.w),
                  _OptionPill(
                    label: _SortOption.values[i].label,
                    selected: sortOption == _SortOption.values[i],
                    onTap: () => onSortSelected(_SortOption.values[i]),
                  ),
                ],
              ],
            ),
          ),
        if (expandedFilter == _FilterKind.level)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                for (
                  var i = 0;
                  i < AccessibilityFitLevel.values.length;
                  i++
                ) ...[
                  if (i > 0) SizedBox(width: 8.w),
                  _OptionPill(
                    label: 'Lv.${i + 1}',
                    selected: minFitLevel == AccessibilityFitLevel.values[i],
                    onTap: () => onMinFitLevelSelected(
                      minFitLevel == AccessibilityFitLevel.values[i]
                          ? null
                          : AccessibilityFitLevel.values[i],
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (expandedFilter != null) SizedBox(height: 8.h),
      ],
    );
  }
}

/// 1차 필터 카테고리/정렬/적합레벨 탭
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 33.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(27.481.r),
          border: Border.all(
            color: isExpanded ? Colors.black : AppColors.boldDivider,
            width: isExpanded ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w500,
                color: isExpanded
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 4.w),
            _Chevron(
              pointsUp: isExpanded,
              color: isExpanded
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.pointsUp, required this.color});

  final bool pointsUp;
  final Color color;

  static const _aspectWidth = 11.6753;
  static const _aspectHeight = 6.98731;
  static const _strokeWidth = 0.916031;

  @override
  Widget build(BuildContext context) {
    final width = 11.r;
    final height = width * _aspectHeight / _aspectWidth;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ChevronPainter(
          pointsUp: pointsUp,
          color: color,
          strokeWidth: width * _strokeWidth / _aspectWidth,
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({
    required this.pointsUp,
    required this.color,
    required this.strokeWidth,
  });

  final bool pointsUp;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (pointsUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 2차 필터 탭
class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 27.481.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(27.481.r),
          border: Border.all(
            color: selected ? Colors.black : AppColors.boldDivider,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SpotListCard extends ConsumerWidget {
  const _SpotListCard({
    required this.spot,
    required this.active,
    required this.distanceMeters,
    required this.selectedFields,
  });

  final TourSpot spot;
  final bool active;
  final double distanceMeters;
  final Set<AccessibilityField> selectedFields;

  Future<void> _handleBookmarkTap(
    BuildContext context,
    WidgetRef ref,
    bool isBookmarked,
  ) async {
    final isGuest = ref.read(authStateProvider).user == null;
    if (isGuest) {
      final goLogin = await showTwoButtonDialog(
        context,
        content: '회원에게만 제공되는 기능입니다.\n로그인 하시겠습니까?',
        primaryLabel: '로그인하기',
        secondaryLabel: '취소',
      );
      if (goLogin == true && context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    if (isBookmarked) {
      ref.read(bookmarkProvider.notifier).unsaveSpot(spot.contentId);
      showAndroidToast(context, '북마크가 해제되었습니다.');
    } else {
      showSaveToFolderSheet(context, ref, spot);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(
      bookmarkProvider.select((state) => state.isSaved(spot.contentId)),
    );
    final fit = calculateAccessibilityFit(
      selectedFields: selectedFields,
      populatedFields: spot.populatedFields,
    );
    final images = [
      if (spot.firstImage != null) spot.firstImage!,
      ...spot.galleryImages,
    ].take(3).toList();
    final facilityLabels = AccessibilityField.values
        .where(spot.populatedFields.contains)
        .take(_kMaxFacilityChips)
        .map((field) => field.label)
        .toList();

    Widget? levelBadge;
    if (!fit.isComputable) {
      levelBadge = const _FitLevelBadge.pending();
    } else if (fit.level != null) {
      levelBadge = _FitLevelBadge.level(fit.level!);
    }

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 여행지 목록 리스트
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: active ? AppColors.background : null,
          border: Border(
            bottom: BorderSide(color: AppColors.hairlineDivider, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          spot.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (levelBadge != null) ...[
                        SizedBox(width: 6.w),
                        levelBadge,
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _handleBookmarkTap(context, ref, isBookmarked),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 32.r,
                    color: isBookmarked
                        ? AppColors.accent
                        : AppColors.navIconInactive,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Text(
                  '${(distanceMeters / 1000).toStringAsFixed(1)}km',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    spot.addr1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            if (facilityLabels.isNotEmpty) ...[
              SizedBox(height: 6.h),
              SizedBox(
                height: 20.h,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < facilityLabels.length; i++) ...[
                        if (i > 0) SizedBox(width: 5.w),
                        _FacilityChip(label: facilityLabels[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 8.h),
            // 여행지 이미지 영역
            LayoutBuilder(
              builder: (context, constraints) {
                final list = images.isEmpty ? const [null] : images;
                final gap = 8.w;
                final cardWidth = (constraints.maxWidth - gap * 2) / 3;
                final cardHeight = cardWidth * 88 / 115;
                return SizedBox(
                  height: cardHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: list[i] == null
                                ? const ImagePlaceholder()
                                : Image.network(
                                    list[i]!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ImagePlaceholder(),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.faintDivider, width: 0.5),
        borderRadius: BorderRadius.circular(2.748.r),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.sp, color: AppColors.textTertiary),
      ),
    );
  }
}

class _FitLevelBadge extends StatelessWidget {
  _FitLevelBadge.level(AccessibilityFitLevel level)
    : label = level.label,
      color = switch (level) {
        AccessibilityFitLevel.lv1 => AppColors.fitLevel1Badge,
        AccessibilityFitLevel.lv2 => AppColors.fitLevel2Badge,
        AccessibilityFitLevel.lv3 => AppColors.fitLevel3Badge,
      };

  const _FitLevelBadge.pending()
    : label = '레벨 산정중',
      color = AppColors.fitLevelPendingBadge;

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
