import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wayable/model/accessibility/accessibility_profile.dart';
import 'package:wayable/model/region/area_code.dart';
import 'package:wayable/providers/navigation_provider.dart';
import 'package:wayable/screen/search/spot_detail_screen.dart';
import 'package:wayable/theme/app_colors.dart';
import 'package:wayable/model/tour/tour_spot.dart';
import 'package:wayable/services/location/location_service.dart';
import 'package:wayable/services/region/area_code_repository.dart';
import 'package:wayable/services/region/kakao_local_service.dart';
import 'package:wayable/services/tour/tour_spot_service.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:wayable/utils/image_cache_size.dart';
import 'package:wayable/widgets/bottom_nav_bar.dart';

const _kCarouselLoopMultiplier = 1000;
const _kHeroAutoPlayInterval = Duration(seconds: 5);

/// 3~5월 봄, 6~8월 여름, 9~11월 가을, 12~2월 겨울.
enum _Season { spring, summer, fall, winter }

_Season _seasonForMonth(int month) {
  if (month >= 3 && month <= 5) return _Season.spring;
  if (month >= 6 && month <= 8) return _Season.summer;
  if (month >= 9 && month <= 11) return _Season.fall;
  return _Season.winter; // 12, 1, 2
}

// TO-DO: 나머지 달(1~7월) 배너 이미지가 준비되면 이 색상+문구 폴백은 걷어낸다.
const _kSeasonGuideColors = {
  _Season.spring: AppColors.seasonSpring,
  _Season.summer: AppColors.seasonSummer,
  _Season.fall: AppColors.seasonFall,
  _Season.winter: Color(0xFF5C6BC0),
};

const _kSeasonLabels = {
  _Season.spring: '봄',
  _Season.summer: '여름',
  _Season.fall: '가을',
  _Season.winter: '겨울',
};

// 월별 안내 슬라이드 이미지. 아직 준비되지 않은 달(1~7월)은 이 맵에 없고,
// 그런 달엔 _buildGuideSlide()가 기존 계절색+문구 폴백을 그대로 보여준다.
const _kMonthGuideImages = {
  8: 'assets/images/home/banner_aug.jpg',
  9: 'assets/images/home/banner_sep.jpg',
  10: 'assets/images/home/banner_oct.jpg',
  11: 'assets/images/home/banner_nov.jpg',
  12: 'assets/images/home/banner_dec.jpg',
};

const _kAccessibilityCardLabels = {
  AccessibilityProfile.physicalAssist: '지체장애 보조',
  AccessibilityProfile.hearingAssist: '청각장애 보조',
  AccessibilityProfile.visionAssist: '시각장애 보조',
  AccessibilityProfile.infantFamily: '영유아 가족',
  AccessibilityProfile.seniorCompanion: '고령자 동반',
};

const _kAccessibilityCardImages = {
  AccessibilityProfile.physicalAssist:
      'assets/images/home/situation_physicalAssist.png',
  AccessibilityProfile.hearingAssist:
      'assets/images/home/situation_hearingAssist.png',
  AccessibilityProfile.visionAssist:
      'assets/images/home/situation_visionAssist.png',
  AccessibilityProfile.infantFamily:
      'assets/images/home/situation_infantFamily.jpg',
  AccessibilityProfile.seniorCompanion:
      'assets/images/home/situation_seniorCompanion.png',
};

const _kAccessibilityCardImageScale = {
  AccessibilityProfile.physicalAssist: 1.15,
  AccessibilityProfile.hearingAssist: 1.3,
  AccessibilityProfile.visionAssist: 1.3,
  AccessibilityProfile.seniorCompanion: 1.15,
};

const _kRankBadgeImages = {
  1: 'assets/images/home/ranking_1st.svg',
  2: 'assets/images/home/ranking_2nd.svg',
  3: 'assets/images/home/ranking_3rd.svg',
  4: 'assets/images/home/ranking_4th.png',
  5: 'assets/images/home/ranking_5th.png',
};

const _kMostSavedCardHeight = 141.0;
// 랭킹 배지가 카드 위로 8만큼 튀어나오는 만큼의 여유 공간.
const _kMostSavedBadgeCushion = 8.0;
// 2등·3등 카드가 1등보다 더 아래로 내려가는 정도.
const _kMostSavedRankDrop = 24.0;
// 장소명 박스가 이미지 박스 하단보다 3만큼 더 아래로 내려가 걸리는 정도.
const _kMostSavedPanelOverhang = 3.0;
// 2등·3등 카드(+장소명 박스 돌출분) 하단이 스크롤뷰 경계에 딱 붙어
// 잘리지 않도록 주는 여유.
const _kMostSavedBottomSafety = 6.0 + _kMostSavedPanelOverhang;

// 장소명 박스 글자 크기·손으로 잡았던 기준 높이(38). [_measureMostSavedPanelHeight]가
// 실측한 값이 이 기준보다 작으면 기준값을 그대로 쓰고(기존 실측 여백 유지),
// 더 필요하면 그만큼만 늘려준다 — 편의칩과 같은 이유([_measureFacilityChipRowHeight]
// 참고)로, 뷰포트 스케일만 따라가는 고정값이면 시스템 글자 크기를 키우거나
// 기기별 폰트 렌더링이 다를 때 이 작은 박스 안 글자가 잘려 보일 수 있다.
const _kMostSavedPanelFontSize = 12.0;
const _kMostSavedPanelVerticalPadding = 12.0;
const _kMostSavedPanelBaselineHeight = 38.0;

class _FeaturedSpot {
  const _FeaturedSpot({required this.spot, required this.regionName});

  final TourSpot spot;
  final String regionName;

  String get contentId => spot.contentId;
  String get title => spot.title;
  String get imageUrl => spot.firstImage!;
}

class _HeroSlide {
  const _HeroSlide.guide() : spot = null;
  const _HeroSlide.spot(this.spot);

  final _FeaturedSpot? spot;

  bool get isGuide => spot == null;
}

class _DiscoverySpot {
  const _DiscoverySpot({
    required this.name,
    required this.location,
    required this.imageUrl,
  });

  final String name;
  final String location;
  final String imageUrl;
}

// 이 시즌(2025년 봄)에 통합필터선택 지역 목록의 첫 번째(서울)가 걸리도록 잡은 기준점.
final _kRegionRotationAnchor = DateTime(2025, 3, 1);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PageController _heroController = PageController();
  int _heroPage = 0;
  // null이면 로딩 중 → _buildHeroBanner()가 스켈레톤을 보여준다.
  List<_FeaturedSpot>? _featuredSpots;
  Timer? _heroAutoPlayTimer;

  final _accessibilityScrollController = ScrollController();
  int _accessibilityCardIndex = 0;

  final _locationService = LocationService();
  final _kakaoLocalService = KakaoLocalService();
  final _tourSpotService = TourSpotService();

  double get _devicePixelRatio => MediaQuery.of(context).devicePixelRatio;

  // null이면 로딩 중 → _buildDiscoverySection()이 실제 값 대신 스켈레톤을 보여준다.
  _DiscoverySpot? _discoverySpot;

  List<TourSpot> _allSpotsWithImages = const [];
  TourSpot? _chosenSpot;
  // GPS로 얻은 SigunguCode
  // null이면 미동의/실패 상태로, 후보가 바뀔 때마다 소속 구를 다시 역참조해 location에 쓴다.
  SigunguCode? _sigungu;
  // 화면 진입 시 한 번만 확정해 새로고침에서도 재사용하는 위치(GPS 재호출 없음).
  // null이면 미동의/실패 상태로, 새로고침은 기존 구 단위 제외 방식으로 폴백한다.
  Position? _position;
  bool _isRefreshingDiscoverySpot = false;

  Map<String, SigunguCode> _sigunguByMemberCode = const {};
  Map<String, AreaCode> _areaCodeBySidoName = const {};

  // null이면 로딩 중 → _buildMostSavedSection()이 스켈레톤을 보여준다.
  List<TourSpot>? _mostSavedSpots;
  StreamSubscription<List<TourSpot>>? _mostSavedSub;

  @override
  void initState() {
    super.initState();
    _loadDiscoverySpot();
    _loadFeaturedSpots();
    _watchMostSavedSpots();
    _accessibilityScrollController.addListener(_onAccessibilityScroll);
  }

  @override
  void dispose() {
    _heroAutoPlayTimer?.cancel();
    _heroController.dispose();
    _accessibilityScrollController.dispose();
    _mostSavedSub?.cancel();
    super.dispose();
  }

  // 북마크 카운트가 바뀌는 순간 실시간 반영되도록 함.
  void _watchMostSavedSpots() {
    _mostSavedSub = _tourSpotService.watchMostBookmarked().listen((spots) {
      AppLogger.debug(
        '[MostSaved] 북마크 : '
        '${spots.where((s) => s.bookmarkCount != 0).map((s) => '${s.title}=${s.bookmarkCount}').join(', ')}',
      );
      final withImages = spots
          .where((spot) => (spot.firstImage ?? '').isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _mostSavedSpots = withImages;
      });
    });
  }

  void _onFeaturedSpotTap(TourSpot spot) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)));
  }

  /// 맞춤 무장애 여행 관련, 대분류 데이터만 가지고 이동함.
  void _onAccessibilityCardTap(AccessibilityProfile profile) {
    ref.read(pendingAccessibilityRequestProvider.notifier).state = profile;
    ref.read(tabSwitchRequestProvider.notifier).state = BottomNavTab.explore;
  }

  void _onAccessibilityScroll() {
    final lastIndex = AccessibilityProfile.values.length - 1;
    final position = _accessibilityScrollController.position;
    final index = position.pixels >= position.maxScrollExtent - 1
        ? lastIndex
        : (position.pixels / (145.w + 7.w)).round().clamp(0, lastIndex);
    if (index != _accessibilityCardIndex) {
      setState(() => _accessibilityCardIndex = index);
    }
  }

  void _startHeroAutoPlay() {
    _heroAutoPlayTimer?.cancel();
    _heroAutoPlayTimer = Timer.periodic(_kHeroAutoPlayInterval, (_) {
      if (!_heroController.hasClients) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadAreaCodeLookups() async {
    final areaCodes = await AreaCodeRepository.load();
    final byMemberCode = <String, SigunguCode>{};
    final bySidoName = <String, AreaCode>{};
    for (final area in areaCodes) {
      bySidoName[_normalizeSidoName(area.name)] = area;
      for (final sigungu in area.sigungu) {
        for (final code in sigungu.memberCodes) {
          byMemberCode[_regionKey(area.code, code)] = sigungu;
        }
      }
      if (area.code == '12') {
        bySidoName['광주'] = area;
        bySidoName['전라남'] = area;
      }
    }
    _sigunguByMemberCode = byMemberCode;
    _areaCodeBySidoName = bySidoName;
  }

  String _regionKey(String? regnCd, String? signguCd) => '$regnCd:$signguCd';

  String _normalizeSidoName(String name) =>
      name.replaceAll(RegExp(r'(특별자치시|특별자치도|광역시|특별시|도)$'), '');

  /// area 안에서만 구 이름을 찾는다 ("중구"처럼 여러 시/도에 겹치는 이름이 있어서, 시/도로 먼저 좁혀야 한다.)
  SigunguCode? _findSigungu(AreaCode? area, String sigunguName) {
    if (area == null) return null;
    for (final sg in area.sigungu) {
      if (sg.name == sigunguName) return sg;
    }
    // 시 + 구가 합쳐진 이름은 ~시 로 재시도.
    final firstToken = sigunguName.split(' ').first;
    for (final sg in area.sigungu) {
      if (sg.name == firstToken) return sg;
    }
    return null;
  }

  /// GPS 동의 시: 위치부터 확정한 뒤 그 좌표 반경 100km 안의 여행지만 후보로
  /// 받아온다(searchNearby) — 후보군 자체가 항상 내 주변으로 좁혀져 있어야,
  /// 그 안에서 역지오코딩으로 구를 매칭하지 못해도 최소한 "내 주변"이라는
  /// 보장은 깨지지 않는다. 예전엔 위치와 무관한 임의의 200건을 먼저 받아온
  /// 뒤 그중 내 구와 겹치는 게 있으면 쓰는 방식이라, 겹치는 게 하나도 없으면
  /// 조용히 그 200건 전체(내 위치와 무관한 전국 표본) 중 랜덤으로 새는
  /// 버그가 있었다.
  /// GPS 미동의/실패: 전체 여행지를 후보로 한다.
  Future<void> _loadDiscoverySpot() async {
    final areaCodesFuture = _loadAreaCodeLookups();
    final positionFuture = _locationService.getCurrentPosition();
    // 새로고침(_refreshDiscoverySpotBySigungu)이 GPS 실패 시 쓸 전국 폴백
    // 풀은 위치 확정 여부와 무관하게 항상 필요해서 미리 같이 받아둔다.
    final fallbackFuture = _tourSpotService.fetchDiscoveryCandidates();

    await areaCodesFuture;
    final position = await positionFuture;
    _position = position;

    final rawSpots = position != null
        ? await _tourSpotService.searchNearby(
            centerLat: position.latitude,
            centerLng: position.longitude,
          )
        : await fallbackFuture;
    final spots = rawSpots
        .where((spot) => (spot.firstImage ?? '').isNotEmpty)
        .toList();
    final fallbackSpots = (await fallbackFuture)
        .where((spot) => (spot.firstImage ?? '').isNotEmpty)
        .toList();

    if (!mounted) return;
    if (spots.isEmpty) {
      setState(() => _allSpotsWithImages = fallbackSpots);
      return;
    }

    var candidates = spots;
    SigunguCode? sigungu;

    if (position != null) {
      final region = await _kakaoLocalService.reverseGeocodeDistrict(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (region != null) {
        final area = _areaCodeBySidoName[_normalizeSidoName(region.sido)];
        final resolved = _findSigungu(area, region.sigungu);
        if (resolved != null) {
          final matched = spots
              .where(
                (spot) =>
                    _sigunguByMemberCode[_regionKey(
                      spot.lDongRegnCd,
                      spot.lDongSignguCd,
                    )] ==
                    resolved,
              )
              .toList();
          // 반경 검색 결과 안에 정확히 내 구와 일치하는 여행지가 없어도
          // (예: 구 경계 근처) candidates는 이미 반경 100km 안이므로 그대로
          // "내 주변" 후보로 쓴다 — 구 라벨만 못 붙일 뿐 전국 랜덤으로
          // 새지 않는다.
          if (matched.isNotEmpty) {
            candidates = matched;
            sigungu = resolved;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _allSpotsWithImages = fallbackSpots;
      _sigungu = sigungu;
      _applySpot(candidates[Random().nextInt(candidates.length)]);
    });
  }

  /// 새로고침 아이콘 탭 핸들러. 위치가 확정돼 있으면(_position) 화면 진입 시
  /// 잡아둔 그 위치를 그대로 재사용해(GPS 재호출 없음) 반경 100km 안에서 랜덤
  /// 재선정하고, 위치가 없으면(미동의/실패) 기존처럼 지금 있는 구를 제외한
  /// 전국 후보에서 랜덤 재선정한다.
  Future<void> _refreshDiscoverySpot() async {
    if (_isRefreshingDiscoverySpot) return;

    final position = _position;
    if (position == null) {
      _refreshDiscoverySpotBySigungu();
      return;
    }

    setState(() => _isRefreshingDiscoverySpot = true);
    try {
      final nearby = await _tourSpotService.searchNearby(
        centerLat: position.latitude,
        centerLng: position.longitude,
        excludeSpotId: _chosenSpot?.contentId,
      );
      final candidates = nearby
          .where((spot) => (spot.firstImage ?? '').isNotEmpty)
          .toList();
      if (candidates.isEmpty) {
        _refreshDiscoverySpotBySigungu();
        return;
      }
      final chosen = candidates[Random().nextInt(candidates.length)];
      final distanceKm =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            chosen.mapY!,
            chosen.mapX!,
          ) /
          1000;
      AppLogger.debug(
        '[Discovery] 새로고침(반경검색): ${chosen.title} - '
        '기준좌표로부터 ${distanceKm.toStringAsFixed(1)}km',
      );
      if (!mounted) return;
      setState(() => _applySpot(chosen));
    } finally {
      if (mounted) setState(() => _isRefreshingDiscoverySpot = false);
    }
  }

  /// 위치 미확정/반경 안 후보 없음일 때의 폴백: 전국 여행지 중 지금 있는 구를
  /// 제외하고 랜덤 재선정.
  void _refreshDiscoverySpotBySigungu() {
    if (_allSpotsWithImages.length <= 1) return;
    final pool = _allSpotsWithImages.where((spot) {
      if (spot.contentId == _chosenSpot?.contentId) return false;
      if (_sigungu == null) return true;
      return _sigunguByMemberCode[_regionKey(
            spot.lDongRegnCd,
            spot.lDongSignguCd,
          )] !=
          _sigungu;
    }).toList();
    if (pool.isEmpty) return;
    setState(() => _applySpot(pool[Random().nextInt(pool.length)]));
  }

  void _applySpot(TourSpot spot) {
    _chosenSpot = spot;
    final location =
        _sigunguByMemberCode[_regionKey(spot.lDongRegnCd, spot.lDongSignguCd)]
            ?.name ??
        spot.addr1;
    _discoverySpot = _DiscoverySpot(
      name: spot.title,
      location: location,
      imageUrl: spot.firstImage!,
    );
  }

  /// KST(UTC+9, 서머타임 없음)로 변환한 현재 시각! 배치(dailyDeltaSync)가 Asia/Seoul 기준이라
  /// 지역 순환도 기기 로컬 시간이 아니라 KST 기준으로 맞춰야 한다.
  DateTime _nowInKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

  int _seasonOrdinal(DateTime date) {
    final bucketYear = date.month == 12 ? date.year + 1 : date.year;
    return bucketYear * 4 + _seasonForMonth(date.month).index;
  }

  /// 통합필터선택 지역 목록의 순서(서울 → 전남광주 → ... → 세종)대로 계절마다 하나씩 순환한다.
  AreaCode _pickThisSeasonsRegion(List<AreaCode> areaCodes) {
    final nowKst = _nowInKst();
    final seasonDiff =
        _seasonOrdinal(nowKst) - _seasonOrdinal(_kRegionRotationAnchor);
    final index = seasonDiff % areaCodes.length;
    return areaCodes[index < 0 ? index + areaCodes.length : index];
  }

  /// dailyDeltaSync(05:00 KST 시작) 배치에 데이터가 많아 언제 끝날지 보장이 안 되므로,
  /// 05:30 KST 전에는 아직 어제 뽑았던 5개를 그대로 보여주고, 05:30부터 오늘 몫으로 새로 랜덤 선정한다.
  DateTime _effectiveDailyDate(DateTime nowKst) {
    final calendarDate = DateTime(nowKst.year, nowKst.month, nowKst.day);
    final isBeforeCutoff =
        nowKst.hour < 5 || (nowKst.hour == 5 && nowKst.minute < 30);
    return isBeforeCutoff
        ? calendarDate.subtract(const Duration(days: 1))
        : calendarDate;
  }

  Future<void> _loadFeaturedSpots() async {
    final areaCodes = await AreaCodeRepository.load();
    final region = _pickThisSeasonsRegion(areaCodes);

    final spots = await _tourSpotService.searchByRegion(region.code);
    final withImages =
        spots.where((spot) => (spot.firstImage ?? '').isNotEmpty).toList()
          ..sort((a, b) => a.contentId.compareTo(b.contentId));

    final dailyDate = _effectiveDailyDate(_nowInKst());
    final dailySeed =
        dailyDate.year * 10000 + dailyDate.month * 100 + dailyDate.day;
    final shuffled = List<TourSpot>.from(withImages)
      ..shuffle(Random(dailySeed));

    final season = _seasonForMonth(_nowInKst().month);
    AppLogger.debug(
      '[HeroBanner] 이번시즌=${_kSeasonLabels[season]} 지역=${region.name}(${region.code}) '
      '전체 스팟=${spots.length}건 사진있음=${withImages.length}건 '
      '일별시드=$dailySeed',
    );

    final featured = shuffled
        .take(5)
        .map((spot) => _FeaturedSpot(spot: spot, regionName: region.name))
        .toList();

    if (!mounted) return;
    final oldController = _heroController;
    final totalSlideCount = featured.isEmpty ? 0 : featured.length + 1;
    final centerVirtualPage = totalSlideCount == 0
        ? 0
        : (totalSlideCount * _kCarouselLoopMultiplier) ~/ 2;
    setState(() {
      _featuredSpots = featured;
      _heroPage = 0;
      _heroController = PageController(initialPage: centerVirtualPage);
    });
    oldController.dispose();
    if (totalSlideCount > 0) _startHeroAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(),
          SizedBox(height: 30.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _buildDiscoverySection(),
          ),
          SizedBox(height: 30.h),
          _buildAccessibilityRecommendationSection(),
          _buildMostSavedSection(),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    final featuredSpots = _featuredSpots;
    // null = 로딩 중, 빈 리스트 = 조회는 끝났는데 사진 있는 여행지가 하나도 없을 경우,
    // 둘 다 스켈레톤으로 처리해 인덱스 접근 크래시를 막는다.
    if (featuredSpots == null || featuredSpots.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 171.h,
        child: _buildSkeletonBox(),
      );
    }

    // 맨 앞은 무조건 안내형 슬라이드, 그 뒤로 추천 여행지가 이어진다.
    final slides = [
      const _HeroSlide.guide(),
      ...featuredSpots.map(_HeroSlide.spot),
    ];
    final currentSlide = slides[_heroPage];

    return SizedBox(
      width: double.infinity,
      height: 171.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _heroController,
            itemCount: slides.length * _kCarouselLoopMultiplier,
            onPageChanged: (index) {
              setState(() => _heroPage = index % slides.length);
              // 페이지가 바뀐 시점부터 다시 5초를 카운트.
              _startHeroAutoPlay();
            },
            itemBuilder: (context, index) {
              final slide = slides[index % slides.length];
              if (slide.isGuide) return _buildGuideSlide();

              final spot = slide.spot!;
              return Semantics(
                label: '${spot.title}, ${spot.regionName} 상세보기',
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _onFeaturedSpotTap(spot.spot),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: spot.imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        memCacheWidth: cacheDimension(1.sw, _devicePixelRatio),
                        memCacheHeight: cacheDimension(
                          171.h,
                          _devicePixelRatio,
                        ),
                        maxWidthDiskCache: cacheDimension(
                          1.sw,
                          _devicePixelRatio,
                        ),
                        maxHeightDiskCache: cacheDimension(
                          171.h,
                          _devicePixelRatio,
                        ),
                        errorWidget: (_, _, _) => _buildImageErrorPlaceholder(),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xCC000000), Color(0x00000000)],
                            stops: [0, 0.5],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 16.h,
            right: 16.w,
            child: ExcludeSemantics(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteBackground.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  '${_heroPage + 1}/${slides.length}',
                  style: TextStyle(
                    fontSize: 8.2.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
          if (!currentSlide.isGuide)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 13.h,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currentSlide.spot!.regionName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      currentSlide.spot!.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection() {
    final spot = _discoverySpot;
    return SizedBox(
      height: 213.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '오늘 발견',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '여행지',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Semantics(
                          label: '다른 여행지 추천받기',
                          button: true,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: _refreshDiscoverySpot,
                            child: Icon(
                              Icons.refresh,
                              size: 22.r,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.pin_drop_outlined,
                      size: 24.r,
                      color: AppColors.locationText,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: spot == null
                          ? _buildSkeletonBox(height: 24.h, widthFraction: 0.7)
                          : Text(
                              spot.location,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.locationText,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 241,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                height: 213.h,
                child: spot == null
                    ? _buildSkeletonBox()
                    : Semantics(
                        label: '${spot.name}, ${spot.location} 상세보기',
                        button: true,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SpotDetailScreen(spot: _chosenSpot!),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: spot.imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.bottomCenter,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                // Row의 flex 120:241 비율대로 나뉜 실제 카드 너비.
                                memCacheWidth: cacheDimension(
                                  (1.sw - 32.w) * 241 / 361,
                                  _devicePixelRatio,
                                ),
                                memCacheHeight: cacheDimension(
                                  213.h,
                                  _devicePixelRatio,
                                ),
                                maxWidthDiskCache: cacheDimension(
                                  (1.sw - 32.w) * 241 / 361,
                                  _devicePixelRatio,
                                ),
                                maxHeightDiskCache: cacheDimension(
                                  213.h,
                                  _devicePixelRatio,
                                ),
                                errorWidget: (_, _, _) =>
                                    _buildImageErrorPlaceholder(),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x1A000000),
                                      Color(0x1A000000),
                                      Color(0xFF000000),
                                      Color(0xFF000000),
                                    ],
                                    stops: [0, 0.692, 0.996, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12.w,
                                right: 13.w,
                                bottom: 12.h,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      spot.name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityRecommendationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '접근성 유형별 여행지 찾기',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '관심 있는 유형에 맞는 맞춤 여행지를 추천해 드려요.',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        SizedBox(
          height: 199.h,
          child: ListView.separated(
            controller: _accessibilityScrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: AccessibilityProfile.values.length,
            separatorBuilder: (_, _) => SizedBox(width: 7.w),
            itemBuilder: (context, index) =>
                _buildAccessibilityCard(AccessibilityProfile.values[index]),
          ),
        ),
        SizedBox(height: 13.h),
        Center(child: _buildAccessibilityIndicator()),
        SizedBox(height: 30.h),
      ],
    );
  }

  Widget _buildAccessibilityCard(AccessibilityProfile profile) {
    final isPhotoAsset = profile == AccessibilityProfile.infantFamily;
    final image = Image.asset(
      _kAccessibilityCardImages[profile]!,
      fit: BoxFit.cover,
      alignment: isPhotoAsset ? Alignment.bottomRight : Alignment.center,
    );
    final label = _kAccessibilityCardLabels[profile]!;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10.r),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: '$label 여행지로 탐색하기',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _onAccessibilityCardTap(profile),
          child: SizedBox(
            width: 145.w,
            child: Stack(
              children: [
                Positioned.fill(
                  child: isPhotoAsset
                      ? image
                      : Transform.scale(
                          scale: _kAccessibilityCardImageScale[profile]!,
                          child: image,
                        ),
                ),
                Positioned(
                  right: 10.w,
                  bottom: 10.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.whiteBackground,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibilityIndicator() {
    final dots = List.generate(AccessibilityProfile.values.length, (index) {
      final isActive = index == _accessibilityCardIndex;
      return Container(
        width: 4.r,
        height: 4.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.primary : AppColors.faintDivider,
        ),
      );
    });
    // 위 카드 목록과 같은 정보(현재 몇 번째 유형인지)를 중복 전달할 뿐이라
    // 스크린 리더에는 노출하지 않는다.
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < dots.length; i++) ...[
            if (i != 0) SizedBox(width: 2.w),
            dots[i],
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({
    double height = double.infinity,
    double? widthFraction,
  }) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.skeletonColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: SizedBox(height: height, width: double.infinity),
    );
    if (widthFraction == null) return box;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFraction,
      child: box,
    );
  }

  Widget _buildGuideSlide() {
    final month = _nowInKst().month;
    final monthImage = _kMonthGuideImages[month];
    if (monthImage != null) {
      return Image.asset(monthImage, fit: BoxFit.cover);
    }

    // 아직 배너 이미지가 없는 달(1~7월)은 기존 계절색+문구 폴백을 보여준다.
    final season = _seasonForMonth(month);
    return DecoratedBox(
      decoration: BoxDecoration(color: _kSeasonGuideColors[season]),
      child: Center(
        child: Text(
          '웨이어블 ${_kSeasonLabels[season]} 이용 안내',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // 사진 URL은 있는데 네트워크 로드 자체가 실패했을 때 쓰는 대체 UI
  Widget _buildImageErrorPlaceholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.skeletonColor),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.black26,
          size: 32.r,
        ),
      ),
    );
  }

  // 실제로 Flutter가 장소명 박스 글자를 그릴 때 쓰는 것과 동일한
  // TextPainter로 필요한 높이를 직접 측정한다 — 뷰포트 스케일이나 텍스트
  // 배율을 손으로 곱해 유추하는 대신이라, 기기·설정과 무관하게 항상
  // 정확히 맞는다([_measureFacilityChipRowHeight]와 같은 방식).
  double _measureMostSavedPanelHeight() {
    final painter = TextPainter(
      text: TextSpan(
        text: '가',
        style: TextStyle(
          fontSize: _kMostSavedPanelFontSize.sp,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height + _kMostSavedPanelVerticalPadding.h * 2;
  }

  Widget _buildMostSavedSection() {
    final spots = _mostSavedSpots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '가장 많이 저장된 여행지',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        SizedBox(
          height:
              (_kMostSavedBadgeCushion +
                      _kMostSavedRankDrop +
                      _kMostSavedCardHeight +
                      _kMostSavedBottomSafety)
                  .h,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: (spots == null || spots.isEmpty)
                ? _buildMostSavedSkeleton()
                : _buildMostSavedRow(spots),
          ),
        ),
        SizedBox(height: 30.h),
      ],
    );
  }

  // 화면상 좌→우 순서는 2등, 1등, 3등이고, 1등만 위쪽에 붙어 더 도드라져 보인다.
  Widget _buildMostSavedRow(List<TourSpot> spots) {
    final order = [if (spots.length >= 2) 1, 0, if (spots.length >= 3) 2];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < order.length; i++) ...[
          if (i != 0) SizedBox(width: 10.w),
          Padding(
            padding: EdgeInsets.only(top: _mostSavedCardTopOffset(order[i])),
            child: _buildMostSavedCard(spots[order[i]], order[i] + 1),
          ),
        ],
      ],
    );
  }

  // rank index(0=1등)별 카드 상단 여백. 배지 튀어나올 여유(_kMostSavedBadgeCushion)를
  // 항상 포함해야 1등 배지 윗부분이 스크롤뷰 경계에 잘리지 않는다.
  double _mostSavedCardTopOffset(int rankIndex) {
    final drop = rankIndex == 0 ? 0.0 : _kMostSavedRankDrop;
    return (_kMostSavedBadgeCushion + drop).h;
  }

  Widget _buildMostSavedSkeleton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMostSavedSkeletonCard(topOffset: _mostSavedCardTopOffset(1)),
        SizedBox(width: 10.w),
        _buildMostSavedSkeletonCard(topOffset: _mostSavedCardTopOffset(0)),
        SizedBox(width: 10.w),
        _buildMostSavedSkeletonCard(topOffset: _mostSavedCardTopOffset(2)),
      ],
    );
  }

  Widget _buildMostSavedSkeletonCard({required double topOffset}) {
    final imageWidth = 103.w;
    final imageHeight = 141.h;
    final panelWidth = 103.w;
    final panelHeight = 38.h;

    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: imageWidth,
              height: imageHeight,
              decoration: BoxDecoration(
                color: AppColors.skeletonColor,
                borderRadius: BorderRadius.circular(15.r),
              ),
            ),
            Positioned(
              top: -8.h,
              left: -8.w,
              child: Container(
                width: 28.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: AppColors.skeletonColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
            Positioned(
              left: (imageWidth - panelWidth) / 2,
              bottom: -_kMostSavedPanelOverhang.h,
              child: Container(
                width: panelWidth,
                height: panelHeight,
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15.r),
                    bottomRight: Radius.circular(15.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(
                    height: 15.h,
                    color: AppColors.skeletonColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostSavedCard(TourSpot spot, int rank) {
    final imageWidth = 103.w;
    final imageHeight = 141.h;
    final panelWidth = 103.w;
    final panelHeight = max(
      _measureMostSavedPanelHeight(),
      _kMostSavedPanelBaselineHeight.h,
    );

    return Semantics(
      label: '저장 인기 $rank위, ${spot.title}',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
        child: SizedBox(
          width: imageWidth,
          height: imageHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15.r),
                child: CachedNetworkImage(
                  imageUrl: spot.firstImage!,
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  memCacheWidth: cacheDimension(imageWidth, _devicePixelRatio),
                  memCacheHeight: cacheDimension(
                    imageHeight,
                    _devicePixelRatio,
                  ),
                  maxWidthDiskCache: cacheDimension(
                    imageWidth,
                    _devicePixelRatio,
                  ),
                  maxHeightDiskCache: cacheDimension(
                    imageHeight,
                    _devicePixelRatio,
                  ),
                  errorWidget: (_, _, _) => _buildImageErrorPlaceholder(),
                ),
              ),
              Positioned(top: -8.h, left: -8.w, child: _buildRankBadge(rank)),
              Positioned(
                left: (imageWidth - panelWidth) / 2,
                bottom: -_kMostSavedPanelOverhang.h,
                child: Container(
                  width: panelWidth,
                  height: panelHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bottomSheetBackground,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(15.r),
                      bottomRight: Radius.circular(15.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    spot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    final path = _kRankBadgeImages[rank]!;
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, width: 28.w, height: 35.h);
    }
    return Image.asset(path, width: 28.w, height: 35.h);
  }
}
