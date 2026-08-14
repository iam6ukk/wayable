import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wayable/model/accessibility/accessibility_profile.dart';
import 'package:wayable/model/region/area_code.dart';
import 'package:wayable/providers/auth_provider.dart';
import 'package:wayable/providers/navigation_provider.dart';
import 'package:wayable/screen/search/spot_detail_screen.dart';
import 'package:wayable/theme/app_colors.dart';
import 'package:wayable/model/tour/tour_spot.dart';
import 'package:wayable/services/location/location_service.dart';
import 'package:wayable/services/region/area_code_repository.dart';
import 'package:wayable/services/region/kakao_local_service.dart';
import 'package:wayable/services/tour/tour_detail_service.dart';
import 'package:wayable/services/tour/tour_spot_service.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:wayable/widgets/bottom_nav_bar.dart';

const _kCarouselLoopMultiplier = 1000;
const _kHeroAutoPlayInterval = Duration(seconds: 5);
const _kMostSavedCardHeight = 203.15;
const _kMostSavedShadowClearance = 10.0;

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
  8: 'assets/images/home/aug.jpg',
  9: 'assets/images/home/sep.jpg',
  10: 'assets/images/home/oct.jpg',
  11: 'assets/images/home/nov.jpg',
  12: 'assets/images/home/dec.jpg',
};

const _kAccessibilityCardLabels = {
  AccessibilityProfile.physicalAssist: '지체장애 맞춤',
  AccessibilityProfile.hearingAssist: '청각장애 맞춤',
  AccessibilityProfile.visionAssist: '시각장애 맞춤',
  AccessibilityProfile.infantFamily: '영유아가족 맞춤',
  AccessibilityProfile.seniorCompanion: '고령자 맞춤',
};

const _kAccessibilityCardImages = {
  AccessibilityProfile.physicalAssist: 'assets/images/home/physical.png',
  AccessibilityProfile.hearingAssist: 'assets/images/home/hearing.png',
  AccessibilityProfile.visionAssist: 'assets/images/home/visual.png',
  AccessibilityProfile.infantFamily: 'assets/images/home/children.jpg',
  AccessibilityProfile.seniorCompanion: 'assets/images/home/elderly.png',
};

const _kAccessibilityCardImageScale = {
  AccessibilityProfile.physicalAssist: 1.15,
  AccessibilityProfile.hearingAssist: 1.3,
  AccessibilityProfile.visionAssist: 1.3,
  AccessibilityProfile.seniorCompanion: 1.15,
};

class _FeaturedSpot {
  const _FeaturedSpot({
    required this.contentId,
    required this.title,
    required this.regionName,
    required this.imageUrl,
  });

  final String contentId;
  final String title;
  final String regionName;
  final String imageUrl;
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
  final _tourDetailService = TourDetailService();

  // null이면 로딩 중 → _buildDiscoverySection()이 실제 값 대신 스켈레톤을 보여준다.
  _DiscoverySpot? _discoverySpot;

  List<TourSpot> _allSpotsWithImages = const [];
  TourSpot? _chosenSpot;
  // GPS로 얻은 SigunguCode
  // null이면 미동의/실패 상태로, 후보가 바뀔 때마다 소속 구를 다시 역참조해 location에 쓴다.
  SigunguCode? _sigungu;

  Map<String, SigunguCode> _sigunguByMemberCode = const {};
  Map<String, AreaCode> _areaCodeBySidoName = const {};
  Map<String, AreaCode> _areaCodeByCode = const {};

  // null이면 로딩 중 → _buildMostSavedSection()이 스켈레톤을 보여준다.
  List<TourSpot>? _mostSavedSpots;
  PageController _mostSavedController = PageController(viewportFraction: 0.402);
  // 히어로 배너처럼 실제 개수보다 훨씬 큰 가상 인덱스를 쓰고 나머지 연산으로
  // 되돌려서, 5번에서 다음으로 넘기면 1번으로 자연스럽게 돌아가게 한다.
  int _mostSavedPage = 0;

  @override
  void initState() {
    super.initState();
    _loadDiscoverySpot();
    _loadFeaturedSpots();
    _loadMostSavedSpots();
    _accessibilityScrollController.addListener(_onAccessibilityScroll);
  }

  @override
  void dispose() {
    _heroAutoPlayTimer?.cancel();
    _heroController.dispose();
    _accessibilityScrollController.dispose();
    _mostSavedController.dispose();
    super.dispose();
  }

  Future<void> _loadMostSavedSpots() async {
    final spots = await _tourSpotService.fetchMostBookmarked();
    final withImages = spots
        .where((spot) => (spot.firstImage ?? '').isNotEmpty)
        .take(5)
        .toList();
    if (!mounted) return;
    final oldController = _mostSavedController;
    final centerVirtualPage = withImages.isEmpty
        ? 0
        : (withImages.length * _kCarouselLoopMultiplier) ~/ 2;
    setState(() {
      _mostSavedSpots = withImages;
      _mostSavedPage = centerVirtualPage;
      _mostSavedController = PageController(
        viewportFraction: 0.402,
        initialPage: centerVirtualPage,
      );
    });
    oldController.dispose();
  }

  void _goToPreviousMostSaved() {
    if (!_mostSavedController.hasClients) return;
    _mostSavedController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToNextMostSaved() {
    if (!_mostSavedController.hasClients) return;
    _mostSavedController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 홈페이지 URL이 있으면 외부 브라우저로 열고, 없으면 아무 동작도 하지 않는다.
  Future<void> _onFeaturedSpotTap(String contentId) async {
    final info = await _tourDetailService.fetchCommonInfo(contentId);
    final homepage = info?.homepage;
    if (homepage == null || homepage.isEmpty) return;
    final uri = Uri.tryParse(homepage);
    if (uri == null) return;
    if (!mounted) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final byCode = <String, AreaCode>{};
    for (final area in areaCodes) {
      bySidoName[_normalizeSidoName(area.name)] = area;
      byCode[area.code] = area;
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
    _areaCodeByCode = byCode;
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

  /// GPS 동의 시: 좌표 → 카카오 역지오코딩으로 얻은 구에 있는 실제 여행지들을 후보로 한다.
  /// GPS 미동의/실패/해당 구에 매칭되는 여행지 없음: 전체 여행지를 후보로 한다.
  Future<void> _loadDiscoverySpot() async {
    final spotsFuture = _tourSpotService.fetchDiscoveryCandidates();
    final areaCodesFuture = _loadAreaCodeLookups();
    final positionFuture = _locationService.getCurrentPosition();
    final rawSpots = await spotsFuture;
    final spots = rawSpots
        .where((spot) => (spot.firstImage ?? '').isNotEmpty)
        .toList();
    if (spots.isEmpty) return;

    await areaCodesFuture;
    final position = await positionFuture;

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
          if (matched.isNotEmpty) {
            candidates = matched;
            sigungu = resolved;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _allSpotsWithImages = spots;
      _sigungu = sigungu;
      _applySpot(candidates[Random().nextInt(candidates.length)]);
    });
  }

  /// 새로고침 아이콘 탭 핸들러: 전국 여행지 중 지금 있는 구를 제외하고 랜덤 재선정
  void _refreshDiscoverySpot() {
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
        .map(
          (spot) => _FeaturedSpot(
            contentId: spot.contentId,
            title: spot.title,
            regionName: region.name,
            imageUrl: spot.firstImage!,
          ),
        )
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
    final nickname = ref.watch(authStateProvider).user?.nickname;
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
          _buildAccessibilityRecommendationSection(nickname),
          _buildMostSavedSection(),
          SizedBox(height: 30.h),
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
              return GestureDetector(
                onTap: () => _onFeaturedSpotTap(spot.contentId),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      spot.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildImageErrorPlaceholder(),
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
              );
            },
          ),
          Positioned(
            top: 16.h,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.pageBadgeBackground,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                '${_heroPage + 1}/${slides.length}',
                style: TextStyle(
                  fontSize: 8.2.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pageBadgeText,
                ),
              ),
            ),
          ),
          if (!currentSlide.isGuide)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 13.h,
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
                        GestureDetector(
                          onTap: _refreshDiscoverySpot,
                          child: Image.asset(
                            'assets/images/refresh.png',
                            width: 22.r,
                            height: 22.r,
                            color: AppColors.textPrimary,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/pin.png',
                      width: 24.r,
                      height: 24.r,
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
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            spot.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomCenter,
                            errorBuilder: (_, _, _) =>
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
                                    fontSize: 19.sp,
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
        ],
      ),
    );
  }

  Widget _buildAccessibilityRecommendationSection(String? nickname) {
    final displayName = (nickname == null || nickname.isEmpty)
        ? '회원'
        : nickname;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$displayName님이 찾던 무장애 여행',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '관심있는 유형에 맞는 맞춤 여행지를 추천해드려요.',
                style: TextStyle(
                  fontSize: 13.sp,
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
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10.r),
      clipBehavior: Clip.antiAlias,
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
                    color: AppColors.pageBadgeBackground,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    _kAccessibilityCardLabels[profile]!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pageBadgeText,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dots.length; i++) ...[
          if (i != 0) SizedBox(width: 2.w),
          dots[i],
        ],
      ],
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
        if (spots == null || spots.isEmpty)
          _buildMostSavedSkeleton()
        else
          SizedBox(
            width: double.infinity,
            height: (_kMostSavedCardHeight + _kMostSavedShadowClearance).h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _mostSavedController,
                  itemCount: spots.length * _kCarouselLoopMultiplier,
                  onPageChanged: (index) =>
                      setState(() => _mostSavedPage = index),
                  itemBuilder: (context, index) {
                    final normalizedIndex = index % spots.length;
                    return AnimatedBuilder(
                      animation: _mostSavedController,
                      builder: (context, _) {
                        var focus = index == _mostSavedPage ? 1.0 : 0.0;
                        if (_mostSavedController.position.haveDimensions) {
                          final page =
                              _mostSavedController.page ??
                              _mostSavedPage.toDouble();
                          final distance = (page - index).abs().clamp(0.0, 1.0);
                          focus = 1 - distance;
                        }
                        return Align(
                          alignment: Alignment.topCenter,
                          child: _buildMostSavedCard(
                            spots[normalizedIndex],
                            normalizedIndex + 1,
                            focus,
                          ),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  left: 16.w,
                  top: 0,
                  bottom: _kMostSavedShadowClearance.h,
                  child: Center(
                    child: _buildCarouselNavButton(
                      'assets/images/left.png',
                      onTap: _goToPreviousMostSaved,
                    ),
                  ),
                ),
                Positioned(
                  right: 16.w,
                  top: 0,
                  bottom: _kMostSavedShadowClearance.h,
                  child: Center(
                    child: _buildCarouselNavButton(
                      'assets/images/right.png',
                      onTap: _goToNextMostSaved,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _truncateLocationToDistrict(String address) {
    final tokens = address.trim().split(RegExp(r'\s+'));
    final districtIndex = tokens.indexWhere((token) => token.endsWith('구'));
    if (districtIndex == -1 || districtIndex >= tokens.length - 1) {
      return address;
    }
    return '${tokens.sublist(0, districtIndex + 1).join(' ')}...';
  }

  Widget _buildMostSavedSkeleton() {
    const sideCardCount = 2;
    final sideWidth = 109.2.w;
    final centerWidth = 154.44.w;
    final gap = 11.5.w;
    final totalRowWidth = sideWidth * sideCardCount + centerWidth + gap * 2;
    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        height: (_kMostSavedCardHeight + _kMostSavedShadowClearance).h,
        child: OverflowBox(
          minWidth: totalRowWidth,
          maxWidth: totalRowWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMostSavedSkeletonCard(focus: 0),
              SizedBox(width: gap),
              _buildMostSavedSkeletonCard(focus: 1),
              SizedBox(width: gap),
              _buildMostSavedSkeletonCard(focus: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMostSavedSkeletonCard({required double focus}) {
    final imageWidth = (lerpDouble(109.2, 154.44, focus)!).w;
    final imageHeight = (lerpDouble(143.64, 203.15, focus)!).h;
    final panelWidthInset = (lerpDouble(0, 21, focus)!).w;
    final panelWidth = imageWidth - panelWidthInset;
    final panelHeight = (lerpDouble(46.2, 78, focus)!).h;
    final panelTop = (lerpDouble(98, 125, focus)!).h;
    final topOffset = (_kMostSavedCardHeight.h - imageHeight) / 2;

    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: SizedBox(
        width: imageWidth,
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
              top: panelTop,
              left: 0,
              child: Container(
                width: panelWidth,
                height: panelHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(10.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: panelWidth * 0.6,
                      height: 10.h,
                      color: AppColors.skeletonColor,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: panelWidth * 0.4,
                      height: 8.h,
                      color: AppColors.skeletonColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostSavedPanelText({
    required String text,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: maxWidth,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 0.85,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildMostSavedCard(TourSpot spot, int rank, double focus) {
    final district =
        _sigunguByMemberCode[_regionKey(spot.lDongRegnCd, spot.lDongSignguCd)]
            ?.name;
    final sidoName = _areaCodeByCode[spot.lDongRegnCd]?.name;
    final rawLocation = district != null && sidoName != null
        ? (sidoName == district ? district : '$sidoName $district')
        : (district ?? spot.addr1);
    final location = _truncateLocationToDistrict(rawLocation);

    final imageWidth = (lerpDouble(109.2, 154.44, focus)!).w;
    final imageHeight = (lerpDouble(143.64, 203.15, focus)!).h;
    final panelWidthInset = (lerpDouble(0, 21, focus)!).w;
    final panelWidth = imageWidth - panelWidthInset;
    final panelHeight = (lerpDouble(46.2, 78, focus)!).h;
    final panelTop = (lerpDouble(98, 125, focus)!).h;
    final titleFontSize = (lerpDouble(9, 15, focus)!).sp;
    final locationFontSize = (lerpDouble(8, 13, focus)!).sp;
    final panelPaddingH = (lerpDouble(10, 12, focus)!).w;
    final panelPaddingTop = (lerpDouble(10, 17, focus)!).h;
    final panelPaddingBottom = (lerpDouble(10, 24, focus)!).h;
    final titleLocationGap = (lerpDouble(5, 10, focus)!).h;
    final badgeOffset = (lerpDouble(5, 7, focus)!);
    final topOffset = (_kMostSavedCardHeight.h - imageHeight) / 2;
    final panelContentWidth = panelWidth - panelPaddingH * 2;

    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.7.w),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          ),
          child: SizedBox(
            width: imageWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15.r),
                  child: Image.network(
                    spot.firstImage!,
                    width: imageWidth,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildImageErrorPlaceholder(),
                  ),
                ),
                Positioned(
                  top: badgeOffset.h,
                  left: badgeOffset.w,
                  child: _buildRankBadge(rank, focus),
                ),
                Positioned(
                  top: panelTop,
                  left: 0,
                  child: Container(
                    width: panelWidth,
                    height: panelHeight,
                    clipBehavior: Clip.antiAlias,
                    padding: EdgeInsets.only(
                      left: panelPaddingH,
                      right: panelPaddingH,
                      top: panelPaddingTop,
                      bottom: panelPaddingBottom,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF000000,
                          ).withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Flexible(
                          child: _buildMostSavedPanelText(
                            text: spot.title,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            maxWidth: panelContentWidth,
                          ),
                        ),
                        SizedBox(height: titleLocationGap),
                        Flexible(
                          child: _buildMostSavedPanelText(
                            text: location,
                            fontSize: locationFontSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            maxWidth: panelContentWidth,
                          ),
                        ),
                      ],
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

  // 등수 이미지: 중앙(focus=1) 28*35, 그 외(focus=0) 22.4*28.
  Widget _buildRankBadge(int rank, double focus) {
    final width = (lerpDouble(22.4, 28, focus)!).w;
    final height = (lerpDouble(28, 35, focus)!).h;
    return Image.asset(
      'assets/images/${rank}st.png',
      width: width,
      height: height,
    );
  }

  Widget _buildCarouselNavButton(String asset, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(asset, width: 32.r, height: 32.r),
    );
  }
}
