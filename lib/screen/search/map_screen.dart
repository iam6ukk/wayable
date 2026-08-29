import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../model/accessibility/accessibility_field.dart';
import '../../model/tour/tour_category.dart';
import '../../model/tour/tour_spot.dart';
import '../../navigation/navigator_key.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/location/location_service.dart';
import '../../services/region/area_code_repository.dart';
import '../../services/region/kakao_local_service.dart';
import '../../services/tour/tour_detail_service.dart';
import '../../services/tour/tour_spot_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/accessibility_fit_level.dart';
import '../../utils/app_logger.dart';
import '../../utils/image_cache_size.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/chevron_icon.dart';
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

/// 정확도순 정렬 3단계 오프셋. 장소명 매칭(인덱스 그대로) < 주소 시/도
/// 매칭(_kSidoRankOffset~) < 주소 그 외(시/군/구 이하) 매칭(_kAddressRankOffset~)
/// 순으로 뒤로 보낸다. 각 인덱스가 현실적으로 수십 자 이내라 이 정도 간격이면
/// 단계끼리 절대 안 섞인다.
///
/// 시/도 단계를 따로 두는 이유: addr1은 "부산광역시 해운대구 ..."처럼 한
/// 줄로 붙어 있어서, 단순 부분일치만 쓰면 "○○군 부산면"처럼 시/군/구 이하
/// 단위에 검색어가 우연히 걸리는 지명과 진짜 그 시/도 소재 여행지를 구분할
/// 수 없다 ("부산" 검색 시 엉뚱한 "부산면"이 먼저 뜨는 문제). addr1의 첫
/// 토큰(시/도)에서 걸리는 매칭만 이 단계로 인정하고, 나머지(시/군/구 이하,
/// addr2)는 한 단계 더 뒤로 보낸다.
const _kSidoRankOffset = 1 << 8;
const _kAddressRankOffset = 1 << 10;

/// 검색어가 있을 때는 카메라 위치와 무관하게 전국 대상으로 찾으므로, 지역
/// 하나로 좁혀서 받던 기존 상한(_regionFetchSafetyLimit=600)과 비슷한
/// 여유치를 둔다 — 정확도 랭킹은 클라이언트에서 매기므로, 서버가 실제
/// 매칭 건수를 다 돌려줘야 상위 [_kMaxMarkers]건이 잘려나가지 않는다.
const _kKeywordSearchPageSize = 600;

/// 활성/비활성 핀 크기. 이미지 자체는 실제 검색결과 화면(831:763 등)에서 쓰인
/// 원본 컴포넌트인 피그마 노드 643:222(Group 147, 활성)/643:221(Group 146, 비활성)를
/// 내려받은 SVG를 래스터화한 asset(assets/images/explore/map_pin_active.png·map_pin_inactive.png).
/// 카카오맵 SDK의 POI 아이콘(KImage.fromAsset)이 비트맵만 지원해 SVG를 직접 쓸 수 없다.
/// (643:224/226은 이름만 비슷한 별도 초안 도형이라 실제로 쓰이는 노드가 아니었음.)
const _kActivePinSize = 32.0;
/// map_pin_inactive.png는 원래 캔버스(72×72) 안에 원이 거의 꽉 차게(약 96%)
/// 그려져 있어서, POI 렌더링 시 다운스케일/안티에일리어싱 여백이 없어 테두리가
/// 살짝 잘려 보였다(활성 핀은 캔버스 대비 원이 약 70%만 차지해 이 문제가 없음).
/// 코드에서 이미지 캔버스를 72→98으로 늘려 원 픽셀은 그대로 두고 여백만
/// 추가했다. 렌더 크기(16)는 그대로 둔다 — 원 지름 보존을 위해 22로 키우면
/// 활성 핀(32)과 크기 차이가 너무 줄어들어 활성/비활성 구분이 잘 안 된다.
/// 그 대신 보이는 원이 이전보다 살짝(약 72%) 작아지는 정도는 감수한다.
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
/// 제목/주소/편의칩/이미지 사이 간격을 전부 [_kCardSectionGap]로 통일한 뒤
/// 실제 콘텐츠 높이에 맞춰 다시 잰 값 — 여유 없이 딱 맞추면 폰트 렌더링
/// 편차로 미세한 오버플로우가 나서 몇 px 여유를 더 둔다. 이미지 영역을
/// 맞춤 여행지 탐색 결과 카드 크기로 키우면서 다시 실측(226 → 250 → 252,
/// 편의칩↔이미지 간격을 [_kCardGapChipsToImage] 참고해 2 늘리면서 같이 조정).
const _kCardExtent = 252.0;

/// 카드 안 제목↔주소, 주소↔편의칩, 편의칩↔이미지 사이 "눈에 보이는" 간격을
/// 전부 주소↔편의칩 간격과 같게 맞추기 위한 값들. 세 SizedBox에 같은 숫자를
/// 넣어도 실제로는 다르게 보였는데, Text 줄은 폰트 자체의 줄간격(leading)이
/// 라인 박스 아래쪽에 얼마씩 남아 SizedBox 여백에 더해지기 때문이다(제목은
/// 15sp 볼드+뱃지라 leading이 커서 더 벌어져 보이고, 이미지는 테두리가
/// 딱 붙는 Container라 leading이 없어 오히려 더 좁아 보였다). 그래서 세
/// 값을 실측해서 다르게 잡아야 시각적으로 동일하게 보인다. 실기기(Note9)
/// 픽셀 실측 결과 주소↔편의칩은 텍스트 줄간격이 더해져 물리 픽셀로 약
/// 28px(디자인 단위 약 10)로 보였는데, 편의칩↔이미지는 (칩 박스가 딱
/// 붙는 Container라 줄간격이 없어서) 값 그대로인 약 22px(디자인 단위 약
/// 8)로 보여 상대적으로 더 좁아 보였다 — 그 차이(~2)만큼
/// [_kCardGapChipsToImage]를 올려 시각적으로 맞춘다.
const _kCardGapTitleToAddress = 0.0;
const _kCardGapAddressToChips = 6.0;
const _kCardGapChipsToImage = 10.0;

/// 카드 위/아래 패딩(각 14, 대칭). 피그마(831:590)를 보면 활성 카드 배경
/// 하이라이트가 위/아래 구분선 사이(카드 셀 전체, 패딩 포함)를 정확히
/// 채우므로, 이 패딩이 비대칭이면 하이라이트 박스 자체도 위아래로 고르지
/// 않게 보인다.
const _kCardVerticalPadding = 14.0;

/// 여행지 이미지 영역 높이(디자인 기준, 172:113 비율의 세로값). 너비를
/// 화면 가로폭(1.sw) 기준으로 계산하던 예전 방식은, 카드 전체 높이
/// ([_kCardExtent])가 세로 스케일(.h)만 따라가는 것과 어긋났다 — 기기의
/// 가로세로 비율이 디자인 기준(360x800)과 정확히 같지 않으면 항상 둘 중
/// 하나가 남거나 넘쳤다(폰마다도 미세하게 남았고, 태블릿처럼 가로로 넓은
/// 화면에서는 크게 넘쳤다). 그래서 이미지 높이 자체를 세로 스케일(.h)
/// 하나로만 고정하고 너비는 거기서 비율로 유도한다 — [_kCardExtent]에서
/// 제목/주소/편의칩 등 나머지 콘텐츠 높이를 뺀 나머지를 실측한 값이라,
/// 화면 비율과 무관하게 항상 카드 높이 예산 안에 정확히 들어맞는다.
const _kResultCardImageHeight = 111.0;

/// 편의칩 글자 크기·패딩·테두리. [_FacilityChip]과 [_measureFacilityChipRowHeight]가
/// 정확히 같은 값을 쓰도록 상수로 뽑아뒀다 — 하나만 바꾸고 다른 하나를
/// 안 바꾸면 다시 잘려 보이는 문제가 재발한다.
// 10.0이었던 걸 11.0으로 소폭 키움 — 받침 있는 글자(출입통로/접근로 등)의
// 획이 실기기에서 물리 픽셀 1~2개 두께라 안티앨리어싱에 따라 흐릿하게
// 보이거나 획이 끊겨 보이는 경우가 있어, 가독성을 위해 올렸다.
const _kFacilityChipFontSize = 11.0;
const _kFacilityChipVerticalPadding = 3.0;
const _kFacilityChipBorderWidth = 0.5;

/// 편의칩 줄(SizedBox) 높이를 "20.h" 같은 손으로 어림한 상수나 뷰포트/텍스트
/// 배율을 곱해 유추한 값 대신, 실제로 Flutter가 그 글자를 그릴 때 쓰는 것과
/// 동일한 [TextPainter]로 직접 측정해서 구한다. 뷰포트 스케일(.h)과 시스템
/// 글자 크기(textScaler)가 서로 다른 축으로 움직이는 데다, 에뮬레이터/실기기
/// 간 폰트 렌더링(hinting) 차이까지 겹쳐서 손으로 계산한 값은 태블릿
/// 에뮬레이터에서 계속 몇 px씩 어긋나 글자가 잘려 보였다 — 직접 측정하면
/// 그 모든 변수를 한 번에 정확히 반영해서 어떤 기기·설정에서도 항상 딱
/// 맞는다.
double _measureFacilityChipRowHeight(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(
      text: '가',
      style: TextStyle(fontSize: _kFacilityChipFontSize.sp),
    ),
    // _FacilityChip이 실제로 쓰는 strutStyle과 반드시 동일해야 측정값과
    // 실제 렌더링 높이가 어긋나지 않는다.
    strutStyle: StrutStyle(
      fontSize: _kFacilityChipFontSize.sp,
      height: 1.0,
      forceStrutHeight: true,
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.height +
      _kFacilityChipVerticalPadding.h * 2 +
      _kFacilityChipBorderWidth * 2;
}

/// 편의칩 줄 높이가 원래 손으로 잡았던 기준값(20.h)보다 더 필요한 만큼만
/// 카드 전체 예산([_kCardExtent])에 더해준다 — 기준값 이하로는 절대 줄지
/// 않아 기존에 실측으로 맞춰둔 카드 여백은 그대로 유지된다.
const _kFacilityChipRowBaseline = 20.0;

/// [_SpotListCard]가 편의칩을 실제로 그리는지와 정확히 같은 기준(카드
/// 위젯의 facilityLabels 계산과 동일한 소스 데이터) — 카드 높이 예산과
/// 실제 렌더링이 어긋나면 리스트 스크롤 위치 계산([_activeIndexForOffset])이
/// 틀어진다.
bool _hasFacilityChips(TourSpot spot) =>
    AccessibilityField.values.any(spot.populatedFields.contains);

double _cardExtentFor(TourSpot spot, double chipRowHeight) {
  final hasChips = _hasFacilityChips(spot);
  final hasImage = spot.firstImage != null;
  // 편의칩이 있을 때만, 실측 칩 줄 높이가 원래 손으로 잡았던 기준값보다
  // 더 필요한 만큼을 추가로 얹는다 — 칩이 아예 없으면 그 줄 자체를 안
  // 그리므로 이 보정도 필요 없다.
  final chipRowExtra = hasChips
      ? (chipRowHeight - _kFacilityChipRowBaseline.h).clamp(
          0.0,
          double.infinity,
        )
      : 0.0;

  // [_kCardExtent]는 원래 "칩 있음 + 이미지 있음" 기준으로 실측한 값이라,
  // 거기서 주소↔칩 간격/칩 줄(기준값)/칩↔이미지 간격/이미지를 전부 뺀
  // 나머지(제목·주소 줄 + 카드 상하 패딩)를 먼저 구한 뒤, [_SpotListCard]가
  // 실제로 그리는 조각만 다시 하나씩 더한다 — 그래야 위젯의 조건부 렌더링
  // (칩 없으면 그 줄 생략, 이미지 없으면 그 영역 생략)과 항상 정확히
  // 맞아떨어진다.
  final fixedPart =
      _kCardExtent.h -
      _kCardGapAddressToChips.h -
      _kFacilityChipRowBaseline.h -
      _kCardGapChipsToImage.h -
      _kResultCardImageHeight.h;

  var extent = fixedPart;
  if (hasChips) {
    extent +=
        _kCardGapAddressToChips.h + _kFacilityChipRowBaseline.h + chipRowExtra;
  } else if (hasImage) {
    // 칩이 없으면 주소↔칩 간격을 그대로 "주소↔이미지" 간격으로 재사용한다
    // ([_SpotListCard.build] 참고).
    extent += _kCardGapAddressToChips.h;
  }
  if (hasImage) {
    extent +=
        (hasChips ? _kCardGapChipsToImage.h : 0.0) + _kResultCardImageHeight.h;
  }
  return extent;
}

const _kSheetHeightFraction = 0.45;
// 시트를 아래로 내렸을 때 남는 최소 높이(필터 pill 줄 정도만 보이는 선) —
// 다시 위로 끌어올릴 수 있는 손잡이 역할을 한다.
const _kSheetMinHeightFraction = 0.16;

/// 편의정보 칩은 카드 한 줄에 다 담기 어려우니 최대 5개까지만 보여준다
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
  const MapScreen({super.key, required this.isActive});

  /// 지금 하단 탭에서 실제로 보이고 있는 탭인지. MainShell이 탭을 떠나도
  /// 이 화면을 지우지 않고 숨겨만 두므로(카카오맵 플랫폼 뷰 깜빡임 방지),
  /// 대신 이 값이 false로 바뀌는 시점을 감지해 검색 상태를 초기화한다.
  final bool isActive;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver, RouteAware {
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
  Key _mapKey = UniqueKey();
  // SpotDetailScreen 등이 Navigator.push로 이 화면 위에 얹히는 동안 true.
  // 탭 전환이 아니라 MainShell의 Offstage가 안 걸리는 경우라, 하이브리드
  // 컴포지션 네이티브 뷰가 그 위에 그대로 비쳐 보이지 않도록 이 플래그가
  // true인 동안은 KakaoMap 위젯 자체를 그리지 않는다([didPushNext]).
  bool _isCoveredByRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 지도 플랫폼 뷰가 만들어지는 동안(onMapReady 호출 전) GPS 조회를 병렬로
    // 미리 시작해서, 지도가 뜨자마자 바로 카메라를 옮길 수 있게 한다.
    _initialPositionFuture = _locationService.getCurrentPosition();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  /// 이 화면(정확히는 MainShell) 위에 다른 라우트가 push되어 이 화면을
  /// 덮었을 때. 탭을 벗어날 때 쓰는 [_recreateMapPlatformView]와 똑같이
  /// 컨트롤러/마커를 정리하고 새 key를 발급해, 가려져 있던 동안의 낡은
  /// 플랫폼 뷰가 그대로 남아있지 않게 한다.
  @override
  void didPushNext() {
    _recreateMapPlatformView();
    if (mounted) setState(() => _isCoveredByRoute = true);
  }

  /// 위에 덮였던 라우트가 pop되어 이 화면이 다시 보일 때. KakaoMap을 다시
  /// 그리면 onMapReady가 새로 호출되어 위치를 재조회하고, 검색 결과가
  /// 남아있었다면 [_handleMapReady]에서 그 결과의 마커도 다시 그린다.
  @override
  void didPopNext() {
    if (mounted) setState(() => _isCoveredByRoute = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.isActive) {
      _recreateMapPlatformView();
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 탭으로 넘어가는 순간(=이 화면이 비활성화되는 순간) 검색 상태를
    // 초기화한다. 카메라 위치(_currentPosition)는 그대로 둔다 — 지도
    // 탭으로 돌아왔을 때 검색 결과까지는 아니어도 보고 있던 위치는 그대로
    // 남아있는 게 자연스럽다.
    if (oldWidget.isActive && !widget.isActive) {
      _resetSearchState();
      _recreateMapPlatformView();
    }
  }

  void _recreateMapPlatformView() {
    if (!mounted) return;
    setState(() {
      _mapController = null;
      _resultMarkers.clear();
      _smallStyles.clear();
      _bigStyles.clear();
      _myLocationMarker = null;
      _mapKey = UniqueKey();
    });
  }

  void _resetSearchState() {
    setState(() {
      _hasSearched = false;
      _isLoading = false;
      _results = const [];
      _activeIndex = 0;
      _selectedCategory = null;
      _sortOption = _SortOption.distance;
      _minFitLevel = null;
      _expandedFilter = null;
      _showInfoTooltip = false;
    });
    _searchController.clear();
    _renderResultMarkers(const []);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    // 이 화면을 벗어날 때 하단 탭 바 숨김 상태가 다른 탭에 남지 않게 되돌린다.
    ref.read(mapResultsActiveProvider.notifier).state = false;
    // 마찬가지로 로컬 뒤로가기 소비 상태도 다른 탭에 남아있으면 그 탭의
    // 정상적인 뒤로가기까지 막아버리니 반드시 꺼둔다.
    ref.read(localBackInterceptActiveProvider.notifier).state = false;
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

  /// 위치를 확정할 때마다 공통으로 하는 일: 로딩 오버레이를 내리고, 내 위치
  /// 상태를 갱신하고(카메라 이동은 [moveCamera]가 true일 때만), 내 위치
  /// 마커를 다시 그린다.
  Future<void> _applyResolvedPosition(
    LatLng latLng, {
    bool moveCamera = true,
  }) async {
    if (!mounted) return;
    setState(() {
      _currentPosition = latLng;
      _isLocating = false;
    });
    if (moveCamera) {
      await _mapController?.moveCamera(
        CameraUpdate.newCenterPosition(latLng, zoomLevel: _kDefaultZoomLevel),
      );
    }
    await _updateMyLocationMarker(latLng);
  }

  Future<void> _handleMapReady(KakaoMapController controller) async {
    _mapController = controller;

    // 정확한 GPS 새 fix는 실내 등에서 최대 8초까지 걸릴 수 있어([LocationService]
    // 타임아웃), 그동안 로딩 화면을 붙잡고 있으면 진입이 너무 느리게 느껴진다.
    // 기기에 캐시된 마지막 위치가 있으면 그걸로 먼저 즉시 지도를 그려서
    // 로딩 체감을 줄이고, 진짜 GPS 결과는 뒤이어 조용히 반영한다.
    //
    // getLastKnownPosition은 (checkPermission과 달리) 위치 권한이 없으면
    // PermissionDeniedException을 던진다 — try/catch 없이 두면 그 아래
    // _applyResolvedPosition이 한 번도 호출되지 못해 _isLocating이 계속
    // true로 남고, 전체화면 LoadingOverlay가 지도를 영영 가려버린다(권한
    // 거부 시에도 지도를 직접 움직여 탐색할 수 있어야 하는데 그게 막힘).
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (_) {
      lastKnown = null;
    }
    final quickLatLng = lastKnown == null
        ? null
        : LatLng(lastKnown.latitude, lastKnown.longitude);
    if (quickLatLng != null) {
      await _applyResolvedPosition(quickLatLng);
    }

    final position = await _initialPositionFuture;
    final latLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : (quickLatLng ?? _kDefaultCenter);

    // 이미 캐시된 위치로 카메라를 옮겨둔 상태에서 실제 GPS 결과가 크게
    // 다르지 않으면(제자리에 서 있던 경우 등) 카메라를 또 움직이지 않는다
    // — 막 지도를 보기 시작한 사용자를 두 번째로 놀래킬 필요는 없다.
    final movedFar = quickLatLng == null || latLng.distance(quickLatLng) > 30;
    await _applyResolvedPosition(latLng, moveCamera: movedFar);

    // 지역코드는 검색 시점에 바로 쓸 수 있게 미리 구해두지만, 실제 검색/마커
    // 렌더링은 사용자가 검색어를 입력하거나 카테고리를 선택했을 때부터 시작한다
    // — 진입 직후에는 지도에 내 위치만 보여야 한다.
    _regionCode = position != null
        ? await _resolveRegionCode(latLng) ?? _kFallbackRegionCode
        : _kFallbackRegionCode;

    // 다른 화면이 덮었다 사라지며([didPopNext]) 플랫폼 뷰가 새로 만들어진
    // 경우, 검색 결과 목록(_results)은 그대로 남아있지만 그 마커들은 이전
    // (지금은 사라진) 컨트롤러에 붙어있던 것들이라 새 컨트롤러에는 하나도
    // 없다 — 다시 그리고, 카메라도 GPS 위치 대신 보고 있던 활성 스팟으로
    // 되돌린다.
    if (_results.isNotEmpty) {
      await _renderResultMarkers(_results);
      await _syncActiveMarkerStyle(0, _activeIndex);
      await _focusCameraOn(_activeIndex);
    }
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

  /// "정확도순"은 검색어와 얼마나 가깝게 일치하는지로 줄을 세운다 — 제목
  /// 안에서 검색어가 더 앞쪽에 나올수록 관련도가 높다고 본다. 검색어가
  /// 없으면 기준으로 삼을 신호가 없어 거리순과 동률로 취급한다.
  ///
  /// 장소명으로 찾는 경우("경복궁")는 사용자가 정확히 아는 곳을 찾는
  /// 강한 신호고, 주소로 찾는 경우는 카카오맵 자체 검색과 마찬가지로
  /// 상대적으로 탐색적인 신호로 본다. 주소 매칭은 다시 두 단계로 나누는데,
  /// addr1의 첫 토큰(시/도, 예: "부산광역시")에서 걸리면 [_kSidoRankOffset]
  /// 단계로, 나머지(시/군/구 이하 또는 addr2)에서만 걸리면 그보다 더 뒤인
  /// [_kAddressRankOffset] 단계로 보낸다. 이렇게 나누지 않으면 "부산"
  /// 검색 시 "○○군 부산면"처럼 시/군/구 이하 단위에 우연히 검색어가 걸린
  /// 지명이, 진짜 부산광역시 소재 여행지와 구분 없이 같은 순위로 섞여버린다.
  int _accuracyRank(TourSpot spot, String keyword) {
    if (keyword.isEmpty) return 0;
    final titleIndex = spot.title.toLowerCase().indexOf(keyword);
    if (titleIndex >= 0) return titleIndex;

    final addr1 = spot.addr1.toLowerCase();
    final tokens = addr1.split(' ');
    final sido = tokens.isNotEmpty ? tokens.first : '';
    final sidoIndex = sido.indexOf(keyword);
    if (sidoIndex >= 0) return _kSidoRankOffset + sidoIndex;

    final address = '$addr1 ${spot.addr2 ?? ''}'.toLowerCase();
    final addressIndex = address.indexOf(keyword);
    if (addressIndex >= 0) return _kAddressRankOffset + addressIndex;

    // 필터(_runSearch)를 이미 통과했다면 이론상 여기 닿지 않는다.
    return 1 << 20;
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
  /// 받아 좌표 있는 장소만 남기고, 키워드(제목·주소 부분일치)·카테고리·최소
  /// 적합레벨로 거른 뒤 선택한 기준으로 정렬해 상위 [_kMaxMarkers]건만
  /// 마커+바텀시트 목록으로 그린다.
  ///
  /// 검색어가 있을 때는 카메라가 보고 있는 지역으로 후보군을 좁히지 않고
  /// 전국 tourSpots를 대상으로 찾는다 — 카메라 위치 기준으로 지역을 먼저
  /// 좁혀버리면, 찾으려는 장소가 그 지역 밖에 있을 때 제목이 정확히
  /// 일치해도 후보군에 아예 못 들어와 못 찾는 문제가 있었다. 검색어 없이
  /// 카테고리만 고르는 탐색은 지금처럼 카메라 위치 기준 지역으로 좁힌다.
  Future<void> _runSearch() async {
    await _syncPositionFromCamera();
    final keyword = _searchController.text.trim().toLowerCase();
    final category = _selectedCategory;

    if (keyword.isEmpty && _regionCode == null) return;

    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });

    final List<TourSpot> spots;
    if (keyword.isNotEmpty) {
      final result = await _tourSpotService.search(
        keyword: keyword,
        categoryIds: category != null ? [category.contentTypeId] : null,
        pageSize: _kKeywordSearchPageSize,
      );
      spots = result.spots;
    } else {
      spots = await _tourSpotService.searchByRegion(
        _regionCode!,
        contentTypeId: category?.contentTypeId,
      );
    }
    final minLevel = _minFitLevel;
    final selectedFields = resolveSelectedFields(
      ref.read(authStateProvider).user,
    );

    final filtered = spots.where((spot) {
      if (spot.mapX == null || spot.mapY == null) return false;
      if (keyword.isNotEmpty) {
        final titleMatches = spot.title.toLowerCase().contains(keyword);
        final addressMatches =
            spot.addr1.toLowerCase().contains(keyword) ||
            (spot.addr2?.toLowerCase().contains(keyword) ?? false);
        if (!titleMatches && !addressMatches) return false;
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
      '[Map] 검색 ${keyword.isNotEmpty ? "전국(keyword)" : "region=$_regionCode"} '
      'keyword="$keyword" category=${category?.label} '
      'sort=${_sortOption.label} minLevel=${minLevel?.label} '
      '결과=${filtered.length}건 (마커=${nearest.length}건)',
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
      'assets/images/explore/map_pin_inactive.png',
      _kInactivePinSize.toInt(),
      _kInactivePinSize.toInt(),
    );
    final bigIcon = KImage.fromAsset(
      'assets/images/explore/map_pin_active.png',
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

  /// 바텀시트를 스크롤해서 활성 카드가 바뀔 때마다 호출된다. 이미지 없는
  /// 카드는 높이가 짧아 카드마다 높이가 다를 수 있어서, 예전처럼 스크롤
  /// offset을 고정 높이로 나누는 대신 카드별 높이를 누적해가며 지금 몇 번째
  /// 카드의 절반을 넘었는지를 찾는다(카드 하나를 완전히 다 넘겨야 바뀌는 게
  /// 아니라 절반쯤 스크롤한 시점에 다음 카드로 넘어가는 동작은 그대로 유지).
  int _activeIndexForOffset(double offset) {
    final chipRowHeight = _measureFacilityChipRowHeight(context);
    var cumulative = 0.0;
    for (var i = 0; i < _results.length; i++) {
      final extent = _cardExtentFor(_results[i], chipRowHeight);
      final midpoint = cumulative + extent / 2;
      if (offset < midpoint) return i;
      cumulative += extent;
    }
    return _results.length - 1;
  }

  void _handleListScroll() {
    final controller = _sheetScrollController;
    if (_isProgrammaticScroll || _results.isEmpty || controller == null) {
      return;
    }
    final index = _activeIndexForOffset(controller.offset);
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

    final chipRowHeight = _measureFacilityChipRowHeight(context);
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
      var targetOffset = 0.0;
      for (var i = 0; i < index; i++) {
        targetOffset += _cardExtentFor(_results[i], chipRowHeight);
      }
      await controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _isProgrammaticScroll = false;
    }
  }

  // _handleMapReady(캐시 위치 → 실제 GPS 위치 순서로 최대 두 번 호출)와
  // _handleMyLocationTap이 겹쳐 호출될 수 있어서, 이 함수가 아직 끝나지
  // 않은 동안 또 호출되면 새 요청은 건너뛴다 — 그렇지 않으면 같은 마커를
  // 두 호출이 동시에 지우려다 두 번째 removePoi가 이미 지워진(무효화된)
  // 네이티브 참조를 건드려 NullPointerException이 나고, 그 뒤로는
  // _myLocationMarker가 무효한 값으로 남아 "내 위치로 이동" 버튼이
  // 계속 먹통이 됐었다.
  bool _isUpdatingMyLocationMarker = false;

  Future<void> _updateMyLocationMarker(LatLng position) async {
    final controller = _mapController;
    if (controller == null || _isUpdatingMyLocationMarker) return;
    _isUpdatingMyLocationMarker = true;
    try {
      if (_myLocationMarker != null) {
        final previousMarker = _myLocationMarker!;
        // 지우는 도중 실패해도 무효한 참조를 계속 들고 있지 않도록 먼저
        // 비워둔다 — removePoi 자체는 실패해도(이미 없는 마커라도) 새
        // 마커를 그리는 데는 지장이 없다.
        _myLocationMarker = null;
        try {
          await controller.labelLayer.removePoi(previousMarker);
        } catch (e) {
          AppLogger.debug('[Map] 이전 내 위치 마커 제거 실패(무시): $e');
        }
      }
      final icon = await KImage.fromWidget(
        const _MyLocationDot(),
        const Size(_kMyLocationDotSize, _kMyLocationDotSize),
      );
      _myLocationMarker = await controller.labelLayer.addPoi(
        position,
        style: PoiStyle(icon: icon),
      );
    } finally {
      _isUpdatingMyLocationMarker = false;
    }
  }

  Future<void> _handleMyLocationTap() async {
    final position = await _locationService.getCurrentPosition(
      forceRefresh: true,
    );
    if (position == null || !mounted) return;

    final latLng = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = latLng);
    await _mapController?.moveCamera(
      CameraUpdate.newCenterPosition(latLng, zoomLevel: _kDefaultZoomLevel),
      animation: const CameraAnimation(300),
    );
    await _updateMyLocationMarker(latLng);
  }

  /// 검색어를 입력해 제출한 시점에만, 기본 정렬을 거리순에서 정확도순으로
  /// 자동 전환한다("부산" 검색 시 우연히 더 가까운 오탐이 거리순에서 먼저
  /// 뜨는 걸 막기 위함). 이후 사용자가 정렬을 직접 다른 걸로 바꾸면 그
  /// 선택을 존중하고, 검색을 완전히 접고 나가면(_resetSearchState) 다시
  /// 거리순으로 돌아간다.
  void _handleSearchSubmitted() {
    if (_searchController.text.trim().isNotEmpty) {
      setState(() => _sortOption = _SortOption.accuracy);
    }
    _runSearch();
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

      // MainShell도 이 화면과 같은 라우트에 PopScope를 두고 있어서, 이 값을
      // 알려주지 않으면 아래 이 화면의 로컬 뒤로가기 처리(필터 접기/검색
      // 상태 초기화)와 MainShell의 탭 이력 되돌리기가 뒤로가기 한 번에
      // 동시에 일어나 버린다. 아래 PopScope의 canPop과 정확히 같은 조건.
      final wantsLocalBack =
          widget.isActive && (_expandedFilter != null || _hasSearched);
      final localBackNotifier = ref.read(
        localBackInterceptActiveProvider.notifier,
      );
      if (localBackNotifier.state != wantsLocalBack) {
        localBackNotifier.state = wantsLocalBack;
      }
    });

    return PopScope(
      // 다른 바텀시트(showModalBottomSheet)는 자체 라우트를 갖고 있어서 뒤로가기가
      // 자동으로 그 라우트만 pop한다. 이 시트는 별도 라우트가 없는 Stack 위젯이라
      // 그대로 두면 뒤로가기가 화면(=앱)까지 pop해버리므로, 검색 결과/펼친 필터가
      // 있을 때는 그것부터 접고 화면 자체는 pop되지 않게 막는다.
      canPop: _expandedFilter == null && !_hasSearched,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_expandedFilter != null) {
          setState(() => _expandedFilter = null);
          return;
        }
        // 시트만 접는 게 아니라 검색 상태 자체를 초기화한다 — 그냥
        // _hasSearched만 false로 돌리면 선택된 카테고리·마커·목록이 그대로
        // 남아있어서, 지도 위 카테고리 칩은 선택된 것처럼 보이는데 그
        // 상태로는 같은 칩을 다시 눌러도 검색이 자연스럽게 이어지지 않았다.
        _resetSearchState();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sheetHeight = constraints.maxHeight * _sheetExtent;

          return Stack(
            children: [
              Positioned.fill(
                // 카카오맵은 네이티브 플랫폼 뷰라 마커 하나하나에 라벨을 붙일
                // 방법이 없다(실기기 uiautomator 덤프로 확인: 이 영역 전체가
                // content-desc 없는 단일 노드). 대신 이 영역 전체를 하나의
                // 안내 노드로 감싸, 스크린 리더 사용자가 지도 대신 아래
                // 목록으로 안내받도록 한다.
                //
                // 이 화면 위에 다른 라우트가 push된 동안([_isCoveredByRoute])은
                // KakaoMap 위젯 자체를 안 그린다 — 하이브리드 컴포지션
                // 네이티브 뷰는 Offstage와 달리 Flutter의 페인트 순서를 따르지
                // 않아서, 그냥 두면 위에 덮인 화면(예: 상세 화면) 위로 그대로
                // 비쳐 보인다.
                child: _isCoveredByRoute
                    ? ColoredBox(color: AppColors.background)
                    : Semantics(
                        label: '지도, 마커 정보는 아래 목록에서 확인할 수 있습니다',
                        excludeSemantics: true,
                        child: KakaoMap(
                          key: _mapKey,
                          option: KakaoMapOption(
                            position: _currentPosition,
                            zoomLevel: _kDefaultZoomLevel,
                          ),
                          onMapReady: _handleMapReady,
                          // 기본(Virtual Display) 모드는 바텀시트 높이 변화
                          // 등으로 뷰가 리사이즈될 때 SurfaceProducer가 이미
                          // 해제된 상태에서 접근해 NPE로 앱이 죽는 경우가
                          // 있었다(kakao_map_sdk 자체 문서에도 기본 모드가
                          // 상태관리 측면에서 문제가 있다고 명시되어 있음).
                          forceHybridComposition: true,
                        ),
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
                  onSubmitted: (_) => _handleSearchSubmitted(),
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
    final activeStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final inactiveStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
    );
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(53.13.r),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.boldDivider,
              width: selected ? 1 : 0.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: _StableWeightLabel(
            label: label,
            style: selected ? activeStyle : inactiveStyle,
            boldStyle: activeStyle,
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
    return Semantics(
      label: '내 위치로 이동',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(9.r),
            child: Icon(
              Icons.my_location,
              size: 22.r,
              color: AppColors.primary,
            ),
          ),
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
    return Semantics(
      label: '이 장소 재검색',
      button: true,
      excludeSemantics: true,
      child: Material(
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
                Icon(
                  Icons.refresh,
                  size: 19.r,
                  color: AppColors.bottomNavActive,
                ),
                SizedBox(width: 4.w),
                Text(
                  '이 장소 재검색',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
                    // 1차 영역 바로 아래 구분선은 _FilterSection이 항상
                    // 그려주므로(펼침 여부와 무관하게 고정 위치), 여기서는
                    // 2차 옵션 줄까지 펼쳐졌을 때 그 아래를 마저 닫는
                    // 구분선만 추가로 그린다.
                    if (expandedFilter != null)
                      Container(height: 0.5.h, color: AppColors.faintDivider),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.bottomSheetBackground,
                  child: _buildBody(context),
                ),
              ),
            ],
          ),
          if (showInfoTooltip)
            Positioned(
              top: 57.h,
              right: 20.w,
              child: Semantics(
                liveRegion: true,
                child: _InfoTooltipBubble(isGuest: isGuest),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // 로딩 중 표시는 전체 화면 LoadingAnimation 오버레이 하나로 통일한다 —
    // 여기서 또 CircularProgressIndicator를 띄우면 로딩 표시가 두 개
    // 겹쳐 보인다.
    if (results.isEmpty) {
      if (isLoading) return const SizedBox.shrink();
      // 그냥 Center만 쓰면 이 안에 스크롤 가능한 위젯이 하나도 없어서,
      // DraggableScrollableSheet가 드래그를 넘겨받을 스크롤 컨트롤러를 못
      // 찾아 결과가 없을 때는 시트를 내렸다 올렸다 할 수 없었다. 실제
      // 내용은 없어도 같은 scrollController를 쓰는 스크롤 영역을 둬서
      // 헤더가 아닌 본문에서도 드래그가 먹게 한다.
      return LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            controller: scrollController,
            // 결과 카드 목록과 같은 이유로 명시한다 — 없으면 MediaQuery
            // 상하 인셋이 자동으로 끼워들어가 중앙 정렬한 문구가 진짜
            // 중앙보다 아래로 처져 보였다.
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Text(
                    '조건에 맞는 여행지가 주변에 없습니다.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textQuaternary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    final chipRowHeight = _measureFacilityChipRowHeight(context);
    return ListView.builder(
      controller: scrollController,
      // ListView는 padding을 안 주면 MediaQuery의 상단 인셋(상태바 높이)을
      // 리스트 맨 위에 자동으로 끼워넣는다(Flutter 기본 동작) — 그 빈
      // 공간이 활성 카드 배경색보다 위에 떠서 구분선과 첫 카드 사이에
      // 색이 다른 여백처럼 보였다. 피그마(831:590)를 보면 활성 카드
      // 배경색이 구분선과 구분선 사이(카드 셀 전체)를 정확히 채우고 그
      // 바깥에는 별도 여백이 없어야 하므로, 리스트는 필터 영역 바로 밑에서
      // 시작해야 한다 — 그래서 여기 별도 padding을 더하지 않는다.
      padding: EdgeInsets.zero,
      // 이미지 없는 여행지는 카드가 더 짧아 항목마다 높이가 다를 수 있어서
      // 고정 itemExtent 대신 항목별로 높이를 계산해주는 빌더를 쓴다.
      itemExtentBuilder: (index, _) =>
          _cardExtentFor(results[index], chipRowHeight),
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
              Semantics(
                label: '적합레벨 안내',
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onInfoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.info_outline,
                    size: 29.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 1차 필터 영역(pill 줄)의 자기 높이는 2차가 열리든 닫히든 항상
        // 같아야 한다 — 2차 옵션 줄은 그 아래에 "추가"되는 것이지, 1차
        // 영역 자체의 경계선(구분선)을 밀어 올리거나 내리면 안 된다. 그래서
        // 이 구분선은 펼침 여부와 무관하게 항상 그리고, 2차 옵션 줄만
        // 조건부로 그 아래에 덧붙인다.
        SizedBox(height: 16.h),
        Container(height: 0.5.h, color: AppColors.faintDivider),
        if (expandedFilter != null) SizedBox(height: 13.h),
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
        if (expandedFilter != null) SizedBox(height: 13.h),
      ],
    );
  }
}

/// 굵기가 바뀌는 라벨(선택/활성 시 볼드)이 폭까지 따라 바뀌어 옆 위젯을
/// 밀어내지 않도록, 안 보이는 텍스트를 가장 굵은 스타일로 뒤에 깔아 자리를
/// 미리 잡아둔다(explore_filter_screen.dart 칩과 같은 기법).
class _StableWeightLabel extends StatelessWidget {
  const _StableWeightLabel({
    required this.label,
    required this.style,
    required this.boldStyle,
  });

  final String label;
  final TextStyle style;
  final TextStyle boldStyle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: Text(label, style: boldStyle)),
        Text(label, style: style),
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
    final activeStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final inactiveStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
    );
    return Semantics(
      label: '$label 필터',
      button: true,
      expanded: isExpanded,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // 통합필터선택 칩과 동일하게 AnimatedContainer로 색/테두리 전환을
        // 부드럽게 하고, 라벨은 _StableWeightLabel로 감싸 굵어져도 pill
        // 너비가 안 흔들리게 한다.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 33.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(27.481.r),
            border: Border.all(
              color: isExpanded ? AppColors.textPrimary : AppColors.boldDivider,
              width: isExpanded ? 1 : 0.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StableWeightLabel(
                label: label,
                style: isExpanded ? activeStyle : inactiveStyle,
                boldStyle: activeStyle,
              ),
              SizedBox(width: 4.w),
              ChevronIcon(
                pointsUp: isExpanded,
                color: isExpanded
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 27.481.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(27.481.r),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.boldDivider,
              width: selected ? 1 : 0.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
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
      final enrichedSpot = await _withGalleryImages(spot);
      if (!context.mounted) return;
      showSaveToFolderSheet(context, ref, enrichedSpot);
    }
  }

  /// 지도 검색 결과 카드는 firstImage 하나만 갖고 있어서, 상세 화면을 거치지
  /// 않고 지도에서 바로 북마크하면 저장목록 화면의 3장짜리 썸네일 줄이
  /// 1장으로만 보인다. 상세 화면(SpotDetailScreen._buildHeader)이 북마크
  /// 저장 시 하는 것과 동일하게, 저장 시점에 갤러리 이미지를 미리 채워서
  /// 저장목록에서도 항상 3장까지 보이게 한다.
  Future<TourSpot> _withGalleryImages(TourSpot spot) async {
    final fetched = await TourDetailService().fetchImages(spot.contentId);
    final gallery = fetched.where((url) => url != spot.firstImage).toList();
    return TourSpot(
      contentId: spot.contentId,
      title: spot.title,
      addr1: spot.addr1,
      addr2: spot.addr2,
      firstImage: spot.firstImage,
      galleryImages: gallery.take(2).toList(),
      contentTypeId: spot.contentTypeId,
      mapX: spot.mapX,
      mapY: spot.mapY,
      lDongRegnCd: spot.lDongRegnCd,
      lDongSignguCd: spot.lDongSignguCd,
      supportedProfiles: spot.supportedProfiles,
      populatedFields: spot.populatedFields,
    );
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

    final Widget levelBadge;
    if (!fit.isComputable) {
      levelBadge = const _FitLevelBadge.pending();
    } else if (fit.level != null) {
      levelBadge = _FitLevelBadge.level(fit.level!);
    } else {
      levelBadge = const _FitLevelBadge.zero();
    }

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, _kCardVerticalPadding.h, 14.w, 12.h),
        decoration: BoxDecoration(
          color: active ? AppColors.background : null,
          border: Border(
            bottom: BorderSide(color: AppColors.faintDivider, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: MergeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            spot.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        levelBadge,
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: isBookmarked ? '북마크 해제' : '북마크 저장',
                  button: true,
                  selected: isBookmarked,
                  excludeSemantics: true,
                  child: GestureDetector(
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
                ),
              ],
            ),
            SizedBox(height: _kCardGapTitleToAddress.h),
            MergeSemantics(
              child: Row(
                children: [
                  Text(
                    '${(distanceMeters / 1000).toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 12.sp,
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
                        fontSize: 12.sp,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 편의정보 칩이 하나도 없는 여행지(이마트/홈플러스 같은 대형마트 등)는
            // 빈 줄 자리를 그대로 잡아두면 주소와 이미지 사이가 뜬금없이
            // 넓어 보인다 — 이미지가 없을 때 그 영역 자체를 그리지 않는
            // 것과 동일하게, 칩이 없으면 이 줄 자체를 통째로 생략한다.
            // 카드 높이도 itemExtentBuilder에서 그만큼 줄여준다([_cardExtentFor]).
            if (facilityLabels.isNotEmpty) ...[
              SizedBox(height: _kCardGapAddressToChips.h),
              SizedBox(
                // 손으로 어림한 고정값 대신 실제 렌더링 높이를 직접 측정한다
                // ([_measureFacilityChipRowHeight] 참고) — 기기·설정에 따라
                // 계속 어긋나던 값이라 여기서 절대 다시 매직 넘버로 되돌리지
                // 말 것.
                height: _measureFacilityChipRowHeight(context),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: MergeSemantics(
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
              ),
            ],
            // 여행지 이미지 영역. 지도 검색 결과는 firstImage 한 장만 갖고
            // 있어서(갤러리는 상세화면에서만 조회) 172:113 비율로 한 장만
            // 보여준다. 높이를 [_kResultCardImageHeight]로 고정하고 너비를
            // 거기서 유도해서, 화면 비율과 무관하게 항상 카드 고정 높이
            // ([_kCardExtent]) 예산 안에 정확히 들어맞는다. 이미지가 아예
            // 없는 여행지는 저장목록 화면과 같이 영역 자체를 안 그린다
            // (플레이스홀더 박스를 띄우지 않음) — 카드 높이도
            // itemExtentBuilder에서 그만큼 줄여준다([_cardExtentFor]).
            if (images.isNotEmpty) ...[
              // 바로 위가 칩 줄이면 칩↔이미지 간격을, 칩이 아예 없어서
              // 주소 줄이 바로 위에 있으면 주소↔이미지 간격을 준다 — 어느
              // 경우든 이미지 앞에는 딱 하나의 간격만 있어야 한다.
              SizedBox(
                height: facilityLabels.isNotEmpty
                    ? _kCardGapChipsToImage.h
                    : _kCardGapAddressToChips.h,
              ),
              SizedBox(
                width: _kResultCardImageHeight.h * 172 / 113,
                height: _kResultCardImageHeight.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: images.first,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    // 관광공사 제공 사진 우하단에 로고가 찍혀있는 경우가
                    // 많아서, 크롭이 생기더라도 그 모서리는 항상
                    // 보존되도록 우하단 기준으로 자른다.
                    alignment: Alignment.bottomRight,
                    memCacheWidth: cacheDimension(
                      _kResultCardImageHeight.h * 172 / 113,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    memCacheHeight: cacheDimension(
                      _kResultCardImageHeight.h,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    maxWidthDiskCache: cacheDimension(
                      _kResultCardImageHeight.h * 172 / 113,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    maxHeightDiskCache: cacheDimension(
                      _kResultCardImageHeight.h,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    errorWidget: (_, _, _) => const ImagePlaceholder(),
                  ),
                ),
              ),
            ],
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
      padding: EdgeInsets.symmetric(
        horizontal: 6.w,
        vertical: _kFacilityChipVerticalPadding.h,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.faintDivider,
          width: _kFacilityChipBorderWidth,
        ),
        borderRadius: BorderRadius.circular(2.748.r),
      ),
      // 이전에는 Transform.translate(0, -1.h)로 글자를 위로 살짝 밀어
      // 세로 중앙에 맞췄는데, -1.h가 기기마다 정수 픽셀이 아닌 값(예:
      // 1.058)이 되면서 텍스트가 정수 픽셀 경계에서 벗어나 렌더링돼
      // 획이 또렷하지 않고 흐릿하게 보였다(특히 받침 있는 글자에서
      // 두드러짐). 페인트 단계에서 위치만 옮기는 대신, 레이아웃 자체의
      // 줄 높이를 폰트 크기와 똑같이 고정해서(strutStyle) 폰트 내부의
      // 비대칭 여백을 없앤다 — 텍스트가 항상 정수 픽셀 경계에서 그려져
      // 선명하다.
      child: Text(
        label,
        textAlign: TextAlign.center,
        strutStyle: StrutStyle(
          fontSize: _kFacilityChipFontSize.sp,
          height: 1.0,
          forceStrutHeight: true,
        ),
        style: TextStyle(
          fontSize: _kFacilityChipFontSize.sp,
          color: AppColors.textTertiary,
        ),
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

  // 매칭률은 계산됐지만 Lv.1 기준(30%)에도 못 미치는 경우.
  const _FitLevelBadge.zero()
    : label = '적합성 Lv.0',
      color = AppColors.fitLevel0Badge;

  const _FitLevelBadge.pending()
    : label = '레벨 산정 중',
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
