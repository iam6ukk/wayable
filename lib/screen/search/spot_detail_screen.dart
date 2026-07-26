import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/tour/tour_accessibility_info.dart';
import '../../model/tour/tour_common_info.dart';
import '../../model/tour/tour_intro_info.dart';
import '../../model/tour/tour_spot.dart';
import '../../services/tour/tour_detail_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/top_logo_banner.dart';
import '../../model/tour/tour_facility_fields.dart';

/// 여행지 상세 화면. 탐색 결과 카드를 눌렀을 때 진입하며, contentId를 기준으로
/// 공통정보(detailCommon2)/소개정보(detailIntro2)/무장애정보(detailWithTour2)를
/// 조회해 시설정보와 편의정보(장애유형별 탭)를 보여준다.
class SpotDetailScreen extends StatefulWidget {
  const SpotDetailScreen({super.key, required this.spot});

  final TourSpot spot;

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _service = TourDetailService();

  bool _isLoading = true;
  bool _isBookmarked = false;
  int _activeAccessibilityTab = 0;

  TourCommonInfo? _common;
  TourIntroInfo? _intro;
  TourAccessibilityInfo? _accessibility;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final results = await Future.wait([
      _service.fetchCommonInfo(widget.spot.contentId),
      _service.fetchIntroInfo(widget.spot.contentId, widget.spot.contentTypeId),
      _service.fetchAccessibilityInfo(widget.spot.contentId),
    ]);

    if (!mounted) return;
    setState(() {
      _common = results[0] as TourCommonInfo?;
      _intro = results[1] as TourIntroInfo?;
      _accessibility = results[2] as TourAccessibilityInfo?;
      _isLoading = false;
    });
  }

  // firstImage2(부가 이미지)는 깨져서 보이는 경우가 많아 원본 이미지(firstImage)만 보여준다.
  List<String> get _images {
    final original = _common?.firstImage ?? widget.spot.firstImage;
    return original == null ? const [] : [original];
  }

  List<_AccessibilityTab> get _accessibilityTabs {
    final accessibility = _accessibility;
    if (accessibility == null) return const [];

    return [
      if (!accessibility.visual.isEmpty)
        _AccessibilityTab('시각장애', _visualEntries(accessibility.visual)),
      if (!accessibility.physical.isEmpty)
        _AccessibilityTab('지체장애', _physicalEntries(accessibility.physical)),
      if (!accessibility.hearing.isEmpty)
        _AccessibilityTab('청각장애', _hearingEntries(accessibility.hearing)),
      if (!accessibility.infantFamily.isEmpty)
        _AccessibilityTab(
          '영유아가족',
          _infantFamilyEntries(accessibility.infantFamily),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.7),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 하단 탭바는 시각적 일관성을 위해 그대로 두되, 이 화면에서는 별도
            // 탭 상태를 갖지 않으므로 어떤 아이콘을 눌러도 이전 화면(MainShell)
            // 으로 돌아가는 것으로 충분하다.
            BottomNavBar(
              currentTab: BottomNavTab.explore,
              onTabSelected: (_) => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _common?.title.isNotEmpty == true
        ? _common!.title
        : widget.spot.title;
    final addr1 = _common?.addr1.isNotEmpty == true
        ? _common!.addr1
        : widget.spot.addr1;
    final addr2 = _common?.addr2;

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
                  fontSize: 21.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textTitle,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isBookmarked = !_isBookmarked),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 28.r,
                color: _isBookmarked
                    ? AppColors.accent
                    : AppColors.iconInactive,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          addr2 == null ? addr1 : '$addr1 $addr2',
          style: TextStyle(fontSize: 12.sp, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final images = _images;

    return AspectRatio(
      aspectRatio: 342 / 189,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: images.isEmpty
            ? _buildImagePlaceholder()
            : Image.network(
                images.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildImagePlaceholder(),
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
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        SizedBox(height: 12.h),
        if (fields == null || fields.isEmpty)
          Text(
            '등록된 시설정보가 없어요',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textEmpty),
          )
        else
          Container(
            // border는 foregroundDecoration으로 그려야 한다: 시설정보 라벨 칸의
            // 불투명 배경색(surfaceLabelColumn)이 가장자리까지 꽉 차 있어서,
            // decoration(배경)에 border를 두면 자식이 그 위에 덮어 그려져 좌측
            // 테두리 선이 끊겨 보였다.
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8.r)),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _facilityFieldRow(fields[i]),
                ],
              ],
            ),
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

  Widget _facilityFieldRow(FacilityFieldSpec spec) {
    final value = _resolveFacilityValue(spec);
    final isEmpty = value == null;
    final isUrl = !isEmpty && _urlPattern.hasMatch(value.trim());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 92.w,
            color: AppColors.surfaceLabelColumn,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            alignment: Alignment.centerLeft,
            child: Text(
              spec.label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: isUrl
                  ? GestureDetector(
                      onTap: () => _openUrl(value.trim()),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 13.sp, color: Colors.black),
                      ),
                    )
                  : Text(
                      isEmpty ? '정보 없음' : value,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isEmpty ? AppColors.textEmpty : Colors.black,
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
    final tabs = _accessibilityTabs;
    final activeIndex = _activeAccessibilityTab < tabs.length
        ? _activeAccessibilityTab
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '편의정보',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        SizedBox(height: 12.h),
        if (tabs.isEmpty)
          Text(
            '등록된 편의정보가 없어요',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textEmpty),
          )
        else ...[
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _AccessibilityTabChip(
                    label: tabs[i].label,
                    isSelected: i == activeIndex,
                    onTap: () => setState(() => _activeAccessibilityTab = i),
                  ),
                ),
              // 탭이 1개뿐일 때 가로 전체로 늘어나지 않도록, 나머지 절반을
              // 빈 슬롯으로 채워 탭 폭을 2개 이상일 때와 동일하게(1/n) 맞춘다.
              if (tabs.length == 1) const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          SizedBox(height: 12.h),
          for (final entry in tabs[activeIndex].entries.entries)
            if (entry.value != null)
              _accessibilityListItem(entry.key.label, entry.value!),
        ],
      ],
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
              width: 4.r,
              height: 4.r,
              decoration: const BoxDecoration(
                color: AppColors.textValue,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLabel,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textValue,
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

class _AccessibilityTab {
  const _AccessibilityTab(this.label, this.entries);

  final String label;
  final Map<AccessibilityField, String?> entries;
}

class _AccessibilityTabChip extends StatelessWidget {
  const _AccessibilityTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.tabInactiveBackground,
          border: Border.all(color: AppColors.tabBorder, width: 0.2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10.r),
            topRight: Radius.circular(10.r),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textValue,
          ),
        ),
      ),
    );
  }
}
