import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wayable/model/region/area_code.dart';
import 'package:wayable/theme/app_colors.dart';
import 'package:wayable/model/tour/tour_spot.dart';
import 'package:wayable/services/location/location_service.dart';
import 'package:wayable/services/region/area_code_repository.dart';
import 'package:wayable/services/region/kakao_local_service.dart';
import 'package:wayable/services/tour/tour_spot_service.dart';
import 'package:wayable/utils/app_logger.dart';

const _kHeroLoopMultiplier = 1000;
const _kHeroAutoPlayInterval = Duration(seconds: 5);

/// 3~5월 봄, 6~8월 여름, 9~11월 가을, 12~2월 겨울.
enum _Season { spring, summer, fall, winter }

_Season _seasonForMonth(int month) {
  if (month >= 3 && month <= 5) return _Season.spring;
  if (month >= 6 && month <= 8) return _Season.summer;
  if (month >= 9 && month <= 11) return _Season.fall;
  return _Season.winter; // 12, 1, 2
}

// TO-DO: 실제 계절별 안내형 슬라이드 디자인으로 교체
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

class _FeaturedSpot {
  const _FeaturedSpot({
    required this.title,
    required this.regionName,
    required this.imageUrl,
  });

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

class _CategorySpot {
  const _CategorySpot({
    required this.label,
    required this.imageAsset,
    required this.background,
    required this.labelColor,
    this.imageAlignment = Alignment.center,
  });

  final String label;
  final String imageAsset;
  final Gradient background;
  final Color labelColor;
  final Alignment imageAlignment;
}

// 이 시즌(2025년 봄)에 통합필터선택 지역 목록의 첫 번째(서울)가 걸리도록 잡은 기준점.
final _kRegionRotationAnchor = DateTime(2025, 3, 1);

final _categorySpots = [
  _CategorySpot(
    label: '문화시설',
    imageAsset: 'assets/images/home/category_culture.png',
    background: const LinearGradient(
      colors: [AppColors.cultureCardColor, AppColors.cultureCardColor],
    ),
    labelColor: Colors.white,
    imageAlignment: Alignment.topCenter,
  ),
  _CategorySpot(
    label: '음식점',
    imageAsset: 'assets/images/home/category_restaurant.png',
    background: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.restaurantCardGradient,
    ),
    labelColor: AppColors.textPrimary,
    imageAlignment: Alignment.center,
  ),
  _CategorySpot(
    label: '숙박',
    imageAsset: 'assets/images/home/category_lodging.png',
    background: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: AppColors.lodgingCardGradient,
    ),
    labelColor: AppColors.textPrimary,
    imageAlignment: Alignment.bottomCenter,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PageController _heroController = PageController();
  int _heroPage = 0;
  // null이면 로딩 중 → _buildHeroBanner()가 스켈레톤을 보여준다.
  List<_FeaturedSpot>? _featuredSpots;
  Timer? _heroAutoPlayTimer;

  final _locationService = LocationService();
  final _kakaoLocalService = KakaoLocalService();
  final _tourSpotService = TourSpotService();

  // null이면 로딩 중 → _buildDiscoverySection()이 실제 값 대신 스켈레톤을 보여준다.
  _DiscoverySpot? _discoverySpot;

  List<TourSpot> _allSpotsWithImages = const [];
  TourSpot? _chosenSpot;
  // GPS로 얻은 SigunguCode
  // null이면 미동의/실패 상태로, 후보가 바뀔 때마다 소속 구를 다시 역참조해 location에 쓴다.
  SigunguCode? _sigungu;

  Map<String, SigunguCode> _sigunguByMemberCode = const {};
  Map<String, AreaCode> _areaCodeBySidoName = const {};

  @override
  void initState() {
    super.initState();
    _loadDiscoverySpot();
    _loadFeaturedSpots();
  }

  @override
  void dispose() {
    _heroAutoPlayTimer?.cancel();
    _heroController.dispose();
    super.dispose();
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
      // 이 데이터셋의 code "12"는 광주광역시 + 전라남도를 합쳐 담고 있어서,
      // 접미사 제거 정규화만으로는 카카오가 실제로 내려주는 "광주광역시"/"전라남도"와 걸리지 않음.
      // 별칭으로 직접 등록
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
      // 위치는 항상 firstImage가 있는 후보 목록에서만 뽑힌다.
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
            title: spot.title,
            regionName: region.name,
            // 위치는 항상 firstImage가 있는 후보 목록에서만 뽑힌다.
            imageUrl: spot.firstImage!,
          ),
        )
        .toList();

    if (!mounted) return;
    final oldController = _heroController;
    // +1은 맨 앞에 고정으로 붙는 안내형 슬라이드
    final totalSlideCount = featured.isEmpty ? 0 : featured.length + 1;
    final centerVirtualPage = totalSlideCount == 0
        ? 0
        : (totalSlideCount * _kHeroLoopMultiplier) ~/ 2;
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
          SizedBox(height: 41.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _buildDiscoverySection(),
          ),
          SizedBox(height: 41.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              '카테고리 별 추천 장소',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          _buildCategoryList(),
          SizedBox(height: 24.h),
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
            itemCount: slides.length * _kHeroLoopMultiplier,
            onPageChanged: (index) {
              setState(() => _heroPage = index % slides.length);
              // 페이지가 바뀐 시점부터 다시 5초를 카운트.
              _startHeroAutoPlay();
            },
            itemBuilder: (context, index) {
              final slide = slides[index % slides.length];
              if (slide.isGuide) return _buildGuideSlide();

              final spot = slide.spot!;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    spot.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildImageErrorPlaceholder(),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.4, 1],
                      ),
                    ),
                  ),
                ],
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
                            width: 14.r,
                            height: 14.r,
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
                      Icons.location_on_outlined,
                      size: 16.r,
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
                                colors: [Color(0x99000000), Color(0x00000000)],
                                stops: [0, 0.5],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12.w,
                            right: 13.w,
                            top: 12.h,
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

  // TO-DO: 실제 계절별 안내형 슬라이드 디자인으로 교체
  Widget _buildGuideSlide() {
    final season = _seasonForMonth(_nowInKst().month);
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

  Widget _buildCategoryList() {
    return SizedBox(
      height: 187.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _categorySpots.length,
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
        itemBuilder: (context, index) =>
            _buildCategoryCard(_categorySpots[index]),
      ),
    );
  }

  // TO-DO : 카테고리별 추천 장소는 제공하기 어려운 이슈로 보류
  Widget _buildCategoryCard(_CategorySpot spot) {
    return Container(
      width: 132.w,
      decoration: BoxDecoration(
        gradient: spot.background,
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.asset(
              spot.imageAsset,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: spot.imageAlignment,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 19.5.w, bottom: 10.h),
            child: Text(
              spot.label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: spot.labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
