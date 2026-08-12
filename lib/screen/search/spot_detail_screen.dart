import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/tour/tour_accessibility_info.dart';
import '../../model/tour/tour_common_info.dart';
import '../../model/tour/tour_intro_info.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/tour/tour_detail_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/chevron_icon.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/top_logo_banner.dart';
import '../../widgets/toast.dart';
import '../../model/tour/tour_facility_fields.dart';
import '../../utils/app_logger.dart';
import '../auth/login_screen.dart';
import '../bookmark/save_to_folder_sheet.dart';

/// 여행지 상세 화면. 탐색 결과 카드를 눌렀을 때 진입하며, contentId를 기준으로
/// 공통정보(detailCommon2)/소개정보(detailIntro2)/무장애정보(detailWithTour2)를
/// 조회해 시설정보와 편의정보(장애유형별 탭)를 보여준다.
class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({super.key, required this.spot});

  final TourSpot spot;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final _service = TourDetailService();

  bool _isLoading = true;

  /// 편의정보 카테고리별 드롭다운 펼침 상태(인덱스 집합).
  Set<int> _expandedCategoryIndices = {};

  TourCommonInfo? _common;
  TourIntroInfo? _intro;
  TourAccessibilityInfo? _accessibility;
  List<String>? _galleryImages;

  final _imagePageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    AppLogger.debug('[SpotDetail] 진입 contentId=${widget.spot.contentId}');
    _loadDetail();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final results = await Future.wait([
      _service.fetchCommonInfo(widget.spot.contentId),
      _service.fetchIntroInfo(widget.spot.contentId, widget.spot.contentTypeId),
      _service.fetchAccessibilityInfo(widget.spot.contentId),
      _service.fetchImages(widget.spot.contentId),
    ]);

    if (!mounted) return;
    setState(() {
      _common = results[0] as TourCommonInfo?;
      _intro = results[1] as TourIntroInfo?;
      _accessibility = results[2] as TourAccessibilityInfo?;
      _galleryImages = results[3] as List<String>;
      _isLoading = false;

      // 편의정보 중 가장 먼저인 카테고리를 기본으로 펼쳐서 보여줌
      if (_accessibilityCategories.isNotEmpty) _expandedCategoryIndices = {0};
    });
  }

  /// 썸네일(detailCommon2의 firstimage)을 맨 앞에 두고, detailImage2로 받아온
  /// 갤러리에서 썸네일과 겹치는 걸 제외한 뒤 최대 3장까지 채운다(썸네일이
  /// 갤러리에도 그대로 들어있는 경우가 있어 중복 제거가 필요하다).
  List<String> get _images {
    final thumbnail = _common?.firstImage ?? widget.spot.firstImage;
    final extras = (_galleryImages ?? const [])
        .where((url) => url != thumbnail)
        .toList();
    return [?thumbnail, ...extras].take(3).toList();
  }

  List<_AccessibilityCategory> get _accessibilityCategories {
    final accessibility = _accessibility;
    if (accessibility == null) return const [];

    final seniorEntries = _seniorEntries(accessibility.physical);

    return [
      if (!accessibility.physical.isEmpty)
        _AccessibilityCategory(
          AccessibilityProfile.physicalAssist,
          _physicalEntries(accessibility.physical),
        ),
      if (!accessibility.hearing.isEmpty)
        _AccessibilityCategory(
          AccessibilityProfile.hearingAssist,
          _hearingEntries(accessibility.hearing),
        ),
      if (!accessibility.visual.isEmpty)
        _AccessibilityCategory(
          AccessibilityProfile.visionAssist,
          _visualEntries(accessibility.visual),
        ),
      if (!accessibility.infantFamily.isEmpty)
        _AccessibilityCategory(
          AccessibilityProfile.infantFamily,
          _infantFamilyEntries(accessibility.infantFamily),
        ),
      if (seniorEntries.values.any((v) => v != null))
        _AccessibilityCategory(
          AccessibilityProfile.seniorCompanion,
          seniorEntries,
        ),
    ];
  }

  void _toggleCategory(int index) {
    setState(() {
      if (!_expandedCategoryIndices.remove(index)) {
        _expandedCategoryIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackground,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const TopLogoBanner(),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 36.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: 16.h),
                        _buildImageCarousel(),
                        SizedBox(height: 28.h),
                        _buildFacilitySection(),
                        SizedBox(height: 28.h),
                        _buildAccessibilitySection(),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Positioned.fill(child: LoadingOverlay()),
                ],
              ),
            ),
            BottomNavBar(
              currentTab: BottomNavTab.explore,
              onTabSelected: (tab) {
                ref.read(tabSwitchRequestProvider.notifier).state = tab;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 비회원이 북마크를 누르면
  /// 마이페이지/저장목록 탭과 동일한 로그인 유도 다이얼로그 띄움
  Future<void> _handleBookmarkTap(
    bool isBookmarked,
    TourSpot resolvedSpot,
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
      ref.read(bookmarkProvider.notifier).unsaveSpot(widget.spot.contentId);
      showAndroidToast(context, '북마크가 해제되었습니다.');
    } else {
      showSaveToFolderSheet(context, ref, resolvedSpot);
    }
  }

  Widget _buildHeader() {
    final title = _common?.title.isNotEmpty == true
        ? _common!.title
        : widget.spot.title;
    final addr1 = _common?.addr1.isNotEmpty == true
        ? _common!.addr1
        : widget.spot.addr1;
    final addr2 = _common?.addr2;
    final isBookmarked = ref.watch(
      bookmarkProvider.select((state) => state.isSaved(widget.spot.contentId)),
    );
    final images = _images;
    final resolvedSpot = TourSpot(
      contentId: widget.spot.contentId,
      title: title,
      addr1: addr1,
      addr2: addr2,
      firstImage: images.isEmpty ? null : images.first,
      // 상세화면에서 스와이프로 보여준 나머지 이미지들도 그대로 저장해서,
      // 저장목록 화면의 3장짜리 썸네일 줄에 각각 다른 사진이 보이게 한다.
      galleryImages: images.length > 1 ? images.sublist(1) : const [],
      contentTypeId: widget.spot.contentTypeId,
      mapX: widget.spot.mapX,
      mapY: widget.spot.mapY,
      lDongRegnCd: widget.spot.lDongRegnCd,
      lDongSignguCd: widget.spot.lDongSignguCd,
      supportedProfiles: widget.spot.supportedProfiles,
      populatedFields: widget.spot.populatedFields,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _handleBookmarkTap(isBookmarked, resolvedSpot),
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
        SizedBox(height: 6.h),
        Text(
          addr2 == null ? addr1 : '$addr1 $addr2',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w300,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final images = _images;

    return AspectRatio(
      // 맞춤 여행지 탐색 결과 카드(explore_screen.dart _ResultCard)와 동일한
      // 비율 — 342:189(1.81)는 관광공사 사진 원본 비율과 차이가 커서 위아래
      // 크롭이 심해지고, 사진 하단의 관광공사 로고가 잘리는 문제가 있었다.
      aspectRatio: 172 / 113,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: images.isEmpty
            ? _buildImagePlaceholder()
            : Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: images.length,
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) => Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        // 관광공사 제공 사진 우하단에 로고가 찍혀있는 경우가
                        // 많아서, 크롭이 생기더라도 그 모서리는 항상
                        // 보존되도록 우하단 기준으로 자른다.
                        alignment: Alignment.bottomRight,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10.h,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          final isActive = index == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: 3.w),
                            width: isActive ? 16.w : 6.w,
                            height: 6.h,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return ImagePlaceholder(iconSize: 32.r);
  }

  /// contentTypeId에 맞는 시설정보 필드 목록(tour_facility_field_config.dart)을
  /// 가져와 라벨/값 테이블로 보여준다. homepage는 항상 공통정보(detailCommon2)에서,
  /// 나머지는 소개정보(detailIntro2) 원본 응답에서 필드명으로 직접 조회한다.
  Widget _buildFacilitySection() {
    final fields = kFacilityFieldsByContentType[widget.spot.contentTypeId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시설정보',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (fields == null || fields.isEmpty)
          Text(
            '등록된 시설정보가 없습니다.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textQuaternary),
          )
        else
          Builder(
            builder: (context) {
              // 라벨마다 따로 줄여버리면(FittedBox를 셀 단위로 적용) "문의처"
              // 처럼 짧은 라벨은 원래 크기 그대로, "이용시간"처럼 긴 라벨만
              // 줄어들어 같은 표 안에서 라벨 글자 크기가 제각각으로 보인다.
              // 표에서 가장 긴 라벨 하나만 기준으로 공통 배율을 구해 모든
              // 라벨에 동일하게 적용해야 크기가 통일되면서도 절대 넘치지
              // 않는다.
              final labelFontSize = _facilityLabelFontSize(context, fields);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: AppColors.faintDivider, width: 0.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.faintDivider,
                        ),
                      _facilityFieldRow(fields[i], labelFontSize),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String? _resolveFacilityValue(FacilityFieldSpec spec) {
    if (spec.source == FacilityFieldSource.common) {
      // homepage는 detailCommon2의 <a href="...">HTML을 순수 URL로 뽑아낸
      // TourCommonInfo.homepage를 그대로 쓴다.
      if (spec.fieldKey == 'homepage') return _common?.homepage;
      return _stringOrNull(_common?.raw[spec.fieldKey]);
    }
    return _stringOrNull(_intro?.raw[spec.fieldKey]);
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    return s.isEmpty ? null : s;
  }

  static final _urlPattern = RegExp(r'^https?://', caseSensitive: false);

  /// 표의 모든 라벨이 같은 크기로 보이도록, 라벨 칸 폭(67.8.w에서 좌우
  /// 패딩 12.w씩을 뺀 값)에 가장 긴 라벨 하나를 기준으로 공통 배율을 구한다.
  /// 셀마다 각자 FittedBox로 줄이면 라벨 글자 수에 따라 축소 비율이 달라져
  /// 같은 표 안에서 라벨 크기가 제각각으로 보이는 문제가 있었다.
  double _facilityLabelFontSize(
    BuildContext context,
    List<FacilityFieldSpec> fields,
  ) {
    const designFontSize = 13.0;
    final baseFontSize = designFontSize.sp;
    final availableWidth = 67.8.w - 24.w;
    final textScaler = MediaQuery.textScalerOf(context);

    var maxWidth = 0.0;
    for (final field in fields) {
      final painter = TextPainter(
        text: TextSpan(
          text: field.label,
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

  Widget _facilityFieldRow(FacilityFieldSpec spec, double labelFontSize) {
    final value = _resolveFacilityValue(spec);
    final isEmpty = value == null;
    final isUrl = !isEmpty && _urlPattern.hasMatch(value.trim());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 67.8.w,
            color: AppColors.surfaceLabelColumn,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.5.h),
            alignment: Alignment.center,
            child: Text(
              spec.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.5.h),
              child: isUrl
                  ? GestureDetector(
                      onTap: () => _openUrl(value.trim()),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : Text(
                      isEmpty ? '정보 없음' : value,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w300,
                        color: isEmpty
                            ? AppColors.textQuaternary
                            : AppColors.textTertiary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildAccessibilitySection() {
    final categories = _accessibilityCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '편의정보',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        SizedBox(height: 4.h),
        if (categories.isEmpty)
          Text(
            '등록된 편의정보가 없습니다.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textQuaternary),
          )
        else
          Text(
            '장애유형별 편의시설 정보를 확인하세요.',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        SizedBox(height: 12.h),
        for (var i = 0; i < categories.length; i++) ...[
          if (i > 0) SizedBox(height: 4.h),
          _buildAccessibilityCategoryCard(categories[i], i),
        ],
      ],
    );
  }

  /// 편의정보 카테고리 하나를 드롭다운 카드로 그린다. 카드 자체나 라벨을 눌러도
  /// 안 열리고, 오른쪽 화살표 아이콘을 눌러야만 펼치고/접는다.
  Widget _buildAccessibilityCategoryCard(
    _AccessibilityCategory category,
    int index,
  ) {
    final isExpanded = _expandedCategoryIndices.contains(index);
    final populatedEntries = category.entries.entries
        .where((entry) => entry.value != null)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isExpanded ? AppColors.background : Colors.transparent,
        border: Border.all(color: AppColors.faintDivider, width: 0.5),
        borderRadius: BorderRadius.circular(5.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              children: [
                Container(
                  width: 30.r,
                  height: 30.r,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category.profile.icon,
                    size: 18.r,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    category.profile.label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleCategory(index),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 28.r,
                    height: 28.r,
                    child: Center(
                      child: ChevronIcon(
                        pointsUp: isExpanded,
                        color: AppColors.boldDivider,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.faintDivider,
              indent: 16.w,
              endIndent: 16.w,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in populatedEntries)
                    _accessibilityListItem(entry.key.label, entry.value!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accessibilityListItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 7.h, right: 8.w),
            child: Container(
              width: 2.r,
              height: 2.r,
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Map<AccessibilityField, String?> _physicalEntries(PhysicalDisabilityInfo p) => {
  AccessibilityField.parking: p.parking,
  AccessibilityField.publicTransport: p.publicTransport,
  AccessibilityField.route: p.route,
  AccessibilityField.ticketOffice: p.ticketOffice,
  AccessibilityField.promotion: p.promotion,
  AccessibilityField.wheelchair: p.wheelchair,
  AccessibilityField.exit: p.exit,
  AccessibilityField.elevator: p.elevator,
  AccessibilityField.restroom: p.restroom,
  AccessibilityField.auditorium: p.auditorium,
  AccessibilityField.room: p.room,
  AccessibilityField.handicapEtc: p.handicapEtc,
};

// 고령자동반은 별도 응답 그룹이 없고 지체장애 필드의 부분집합을 그대로 쓰므로,
// AccessibilityFieldMapping(공유 매핑 정의)에서 어떤 필드를 쓸지 가져와 지체장애
// 데이터에서 해당 값만 추려낸다.
Map<AccessibilityField, String?> _seniorEntries(PhysicalDisabilityInfo p) {
  final physicalEntries = _physicalEntries(p);
  final seniorFields =
      AccessibilityFieldMapping.mapping[AccessibilityProfile.seniorCompanion] ??
      const <AccessibilityField>[];
  return {for (final field in seniorFields) field: physicalEntries[field]};
}

Map<AccessibilityField, String?> _visualEntries(VisualDisabilityInfo v) => {
  AccessibilityField.braileBlock: v.braileBlock,
  AccessibilityField.helpDog: v.helpDog,
  AccessibilityField.guideHuman: v.guideHuman,
  AccessibilityField.audioGuide: v.audioGuide,
  AccessibilityField.bigPrint: v.bigPrint,
  AccessibilityField.brailePromotion: v.brailePromotion,
  AccessibilityField.guideSystem: v.guideSystem,
  AccessibilityField.blindHandicapEtc: v.blindHandicapEtc,
};

Map<AccessibilityField, String?> _hearingEntries(HearingDisabilityInfo h) => {
  AccessibilityField.signGuide: h.signGuide,
  AccessibilityField.videoGuide: h.videoGuide,
  AccessibilityField.hearingRoom: h.hearingRoom,
  AccessibilityField.hearingHandicapEtc: h.hearingHandicapEtc,
};

Map<AccessibilityField, String?> _infantFamilyEntries(InfantFamilyInfo f) => {
  AccessibilityField.stroller: f.stroller,
  AccessibilityField.lactationRoom: f.lactationRoom,
  AccessibilityField.babySpareChair: f.babySpareChair,
  AccessibilityField.infantsFamilyEtc: f.infantsFamilyEtc,
};

class _AccessibilityCategory {
  const _AccessibilityCategory(this.profile, this.entries);

  final AccessibilityProfile profile;
  final Map<AccessibilityField, String?> entries;
}
