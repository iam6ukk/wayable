import 'package:flutter/material.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/tour/tour_accessibility_info.dart';
import '../../model/tour/tour_common_info.dart';
import '../../model/tour/tour_intro_info.dart';
import '../../model/tour/tour_spot.dart';
import '../../services/tour/tour_detail_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/top_logo_banner.dart';
import 'tour_field_labels_debug.dart';

const _kPrimaryBlue = Color(0xFF0065F4);
const _kSectionTitleColor = Color(0xFF060606);
const _kLabelTextColor = Color(0xFF3C3C3C);
const _kValueTextColor = Color(0xFF868686);
const _kEmptyValueColor = Color(0xFFACACAC);
const _kDividerColor = Color(0xFFE3E3E3);
const _kInactiveIconColor = Color(0xFF7D7D7D);
const _kInactiveCircleBg = Color(0xFFF2F2F2);
const _kTabInactiveBg = Color(0xFFF0F0F0);
const _kTabBorderColor = Color(0xFF8F8F8F);

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
  final _imagePageController = PageController();

  bool _isLoading = true;
  bool _isBookmarked = false;
  int _imagePage = 0;
  int _activeAccessibilityTab = 0;

  TourCommonInfo? _common;
  TourIntroInfo? _intro;
  TourAccessibilityInfo? _accessibility;

  @override
  void initState() {
    super.initState();
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
    ]);

    if (!mounted) return;
    setState(() {
      _common = results[0] as TourCommonInfo?;
      _intro = results[1] as TourIntroInfo?;
      _accessibility = results[2] as TourAccessibilityInfo?;
      _isLoading = false;
    });
  }

  List<String> get _images {
    final images = _common?.images ?? const <String>[];
    if (images.isNotEmpty) return images;
    final fallback = widget.spot.firstImage;
    return fallback == null ? const [] : [fallback];
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

  void _goToImagePage(int delta) {
    final target = (_imagePage + delta).clamp(0, _images.length - 1);
    _imagePageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildImageCarousel(),
                        const SizedBox(height: 28),
                        _buildFacilitySection(),
                        const SizedBox(height: 28),
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
                          color: _kPrimaryBlue,
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
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: _kSectionTitleColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isBookmarked = !_isBookmarked),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 28,
                color: _isBookmarked ? _kPrimaryBlue : _kInactiveIconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          addr2 == null ? addr1 : '$addr1 $addr2',
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final images = _images;

    return AspectRatio(
      aspectRatio: 342 / 189,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: images.isEmpty
            ? _buildImagePlaceholder()
            : Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _imagePageController,
                    itemCount: images.length,
                    onPageChanged: (page) => setState(() => _imagePage = page),
                    itemBuilder: (context, index) => Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
                    ),
                  ),
                  if (images.length > 1) ...[
                    Positioned(
                      left: 8,
                      child: _CarouselArrowButton(
                        icon: Icons.chevron_left,
                        onTap: _imagePage == 0 ? null : () => _goToImagePage(-1),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      child: _CarouselArrowButton(
                        icon: Icons.chevron_right,
                        onTap: _imagePage == images.length - 1
                            ? null
                            : () => _goToImagePage(1),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: _kInactiveCircleBg,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: _kInactiveIconColor,
      ),
    );
  }

  // TODO(임시 디버그 뷰): 컨텐츠타입별로 시설정보에 어떤 필드를 보여줄지 아직
  // 확정 전이라, detailCommon2/detailIntro2 원본 응답을 필드 단위로 전부
  // 펼쳐서 보여준다. 항목이 확정되면 컨텐츠타입별 필드 매핑 표로 되돌리고
  // tour_field_labels_debug.dart도 함께 정리한다.
  Widget _buildFacilitySection() {
    final commonRaw = _common?.raw ?? const {};
    final introRaw = _intro?.raw ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시설정보 (원본 데이터 확인용 임시 뷰)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kSectionTitleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'contentId: ${widget.spot.contentId} · contentTypeId: ${widget.spot.contentTypeId}',
          style: const TextStyle(fontSize: 12, color: _kValueTextColor),
        ),
        const SizedBox(height: 16),
        _rawSectionTitle('공통정보 원본 (detailCommon2)'),
        const SizedBox(height: 8),
        if (commonRaw.isEmpty)
          _rawEmptyText()
        else
          ..._buildRawRows(commonRaw, kCommonFieldLabelsDebug),
        const SizedBox(height: 20),
        _rawSectionTitle('소개정보 원본 (detailIntro2)'),
        const SizedBox(height: 8),
        if (introRaw.isEmpty)
          _rawEmptyText()
        else
          ..._buildRawRows(introRaw, kIntroFieldLabelsDebug),
      ],
    );
  }

  Widget _rawSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _kPrimaryBlue,
      ),
    );
  }

  Widget _rawEmptyText() {
    return const Text(
      '조회된 데이터가 없어요',
      style: TextStyle(fontSize: 13, color: _kEmptyValueColor),
    );
  }

  List<Widget> _buildRawRows(
    Map<String, dynamic> raw,
    Map<String, String> labels,
  ) {
    return [
      for (final entry in raw.entries)
        if (entry.key != 'contentid' && entry.key != 'contenttypeid')
          _rawFieldRow(
            entry.key,
            labels[entry.key] ?? '(라벨 미확인)',
            entry.value?.toString(),
          ),
    ];
  }

  Widget _rawFieldRow(String fieldName, String label, String? value) {
    final isEmpty = value == null || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fieldName,
                style: const TextStyle(fontSize: 11, color: _kValueTextColor),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kLabelTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isEmpty ? '(빈값)' : value,
            style: TextStyle(
              fontSize: 13,
              color: isEmpty ? _kEmptyValueColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilitySection() {
    final tabs = _accessibilityTabs;
    final activeIndex = _activeAccessibilityTab < tabs.length
        ? _activeAccessibilityTab
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '편의정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kSectionTitleColor,
          ),
        ),
        const SizedBox(height: 12),
        if (tabs.isEmpty)
          const Text(
            '등록된 편의정보가 없어요',
            style: TextStyle(fontSize: 14, color: _kEmptyValueColor),
          )
        else ...[
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _AccessibilityTabChip(
                  label: tabs[i].label,
                  isSelected: i == activeIndex,
                  onTap: () => setState(() => _activeAccessibilityTab = i),
                ),
              ],
            ],
          ),
          const Divider(height: 1, thickness: 0.5, color: _kDividerColor),
          const SizedBox(height: 12),
          for (final entry in tabs[activeIndex].entries.entries)
            if (entry.value != null) _accessibilityListItem(entry.key.label, entry.value!),
        ],
      ],
    );
  }

  Widget _accessibilityListItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: _kValueTextColor,
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kLabelTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: _kValueTextColor),
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
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _kPrimaryBlue : _kTabInactiveBg,
          border: Border.all(color: _kTabBorderColor, width: 0.2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : _kValueTextColor,
          ),
        ),
      ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  const _CarouselArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white,
        ),
      ),
    );
  }
}
