import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
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

  /// 편의정보 카테고리별 드롭다운 펼침 상태(인덱스 집합).
  Set<int> _expandedCategoryIndices = {};

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

      // 편의정보 중 가장 먼저인 카테고리를 기본으로 펼쳐서 보여줌
      if (_accessibilityCategories.isNotEmpty) _expandedCategoryIndices = {0};
    });
  }

  List<String> get _images {
    final original = _common?.firstImage ?? widget.spot.firstImage;
    return original == null ? const [] : [original];
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
                    Positioned.fill(
                      child: Container(
                        color: AppColors.whiteBackground.withValues(alpha: 0.7),
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
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isBookmarked = !_isBookmarked),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 28.r,
                color: _isBookmarked ? AppColors.accent : AppColors.boldDivider,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          addr2 == null ? addr1 : '$addr1 $addr2',
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
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
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (fields == null || fields.isEmpty)
          Text(
            '등록된 시설정보가 없어요',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textQuaternary),
          )
        else
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8.r)),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: AppColors.faintDivider),
              borderRadius: BorderRadius.circular(8.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.faintDivider),
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
                color: AppColors.textSecondary,
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
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Text(
                      isEmpty ? '정보 없음' : value,
                      style: TextStyle(
                        fontSize: 13.sp,
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
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        SizedBox(height: 4.h),
        if (categories.isEmpty)
          Text(
            '등록된 편의정보가 없어요',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textQuaternary),
          )
        else
          Text(
            '장애유형별 편의시설 정보를 확인하세요.',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        SizedBox(height: 12.h),
        for (var i = 0; i < categories.length; i++) ...[
          if (i > 0) SizedBox(height: 8.h),
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
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Container(
                  width: 32.r,
                  height: 32.r,
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
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleCategory(index),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20.r,
                      color: AppColors.textSecondary,
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
              indent: 12.w,
              endIndent: 12.w,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
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
              width: 4.r,
              height: 4.r,
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
// 데이터에서 해당 값만 추려낸다. 필드 목록을 여기서 다시 하드코딩하지 않는 이유는
// 매핑이 바뀌었을 때 두 곳(탐색 화면의 supportedProfiles 계산과 여기)이 어긋나지
// 않게 하기 위함이다.
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
