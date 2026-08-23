import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

import '../../model/accessibility/accessibility_profile.dart';
import '../../model/bookmark/bookmark_folder.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/bookmark_provider.dart';
import '../../services/location/location_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/image_cache_size.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/scroll_fab.dart';
import '../../widgets/toast.dart';
import '../search/spot_detail_screen.dart';
import 'folder_edit_screen.dart';

class SavedListScreen extends ConsumerStatefulWidget {
  const SavedListScreen({super.key});

  @override
  ConsumerState<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends ConsumerState<SavedListScreen>
    with TickerProviderStateMixin {
  // 폴더 개수가 바뀌면 예전 TabController를 다음 프레임에 지우는 동안(디스포즈
  // 지연) 잠깐 새 컨트롤러와 동시에 존재하므로, 한 번에 하나만 허용하는
  // SingleTickerProviderStateMixin으로는 "multiple tickers were created" 에러가
  // 난다 — 여러 개를 허용하는 TickerProviderStateMixin을 써야 한다.
  late TabController _tabController;
  bool _showFolderEdit = false;

  // 순서 편집 모드 여부. FolderEditScreen 안의 로컬 상태가 아니라 여기서
  // 들고 있어야, 뒤로가기를 눌렀을 때 "순서 편집 → 폴더 편집 → 저장 목록"
  // 순으로 한 단계씩만 빠져나가게 만들 수 있다(PopScope 핸들러 참고).
  bool _isFolderReorderMode = false;
  int _lastFolderCount = 0;

  // 상하단 이동 버튼은 현재 보이는 탭의 목록을 스크롤해야 하는데, 탭마다
  // ListView(및 그 ScrollController)를 소유한 _FolderSpotList가 각각 독립된
  // State라서 부모가 직접 만들 수 없다. 대신 각 _FolderSpotList가 자기
  // ScrollController를 만든 다음 폴더 id로 등록해주면, 버튼은 현재 탭 인덱스에
  // 해당하는 폴더 id로 컨트롤러를 찾아 스크롤만 시킨다.
  final Map<String, ScrollController> _folderScrollControllers = {};

  // 카드마다 GPS를 따로 조회하지 않고, 화면 진입 시 한 번만 구해서 모든
  // 폴더 탭의 카드가 같은 현재 위치 기준으로 거리를 계산하게 공유한다.
  final _locationService = LocationService();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _lastFolderCount = ref.read(bookmarkProvider).folders.length;
    _tabController = TabController(length: _lastFolderCount, vsync: this);
    _loadCurrentPosition();
  }

  /// 이 탭을 벗어났다 다시 들어올 때마다 State가 새로 만들어져 매번 GPS
  /// 새 fix를 기다리면 거리 표시가 한 박자 늦게 뜬다. 기기에 캐시된 마지막
  /// 위치가 있으면 그걸로 먼저 즉시 보여준 뒤, 최신 위치가 도착하면 이어서
  /// 갱신한다.
  Future<void> _loadCurrentPosition() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      setState(() => _currentPosition = lastKnown);
    }
    final fresh = await _locationService.getCurrentPosition();
    if (fresh != null && mounted) {
      setState(() => _currentPosition = fresh);
    }
  }

  void _registerFolderScrollController(
    String folderId,
    ScrollController controller,
  ) {
    _folderScrollControllers[folderId] = controller;
  }

  void _unregisterFolderScrollController(String folderId) {
    _folderScrollControllers.remove(folderId);
  }

  void _scrollActiveTab(double Function(ScrollController controller) target) {
    final folders = ref.read(bookmarkProvider).folders;
    if (folders.isEmpty) return;
    final activeIndex = _tabController.index.clamp(0, folders.length - 1);
    final controller = _folderScrollControllers[folders[activeIndex].id];
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      target(controller),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() => _scrollActiveTab((_) => 0);

  void _scrollToBottom() => _scrollActiveTab((c) => c.position.maxScrollExtent);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 폴더 추가/삭제로 개수가 바뀔 때만 호출한다 — 이름 변경은 길이가 그대로라
  /// TabController를 새로 만들 필요가 없다.
  void _rebuildTabController(int folderCount) {
    final oldController = _tabController;
    final newIndex = oldController.index.clamp(0, folderCount - 1);
    _tabController = TabController(
      length: folderCount,
      vsync: this,
      initialIndex: newIndex,
    );
    _lastFolderCount = folderCount;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => oldController.dispose(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(bookmarkProvider).folders;
    if (folders.length != _lastFolderCount) {
      _rebuildTabController(folders.length);
    }

    if (_showFolderEdit) {
      // 이 화면은 별도 라우트 없이 SavedListScreen 콘텐츠만 갈아끼운 것이라,
      // 그대로 두면 시스템 뒤로가기가 화면(=앱)까지 pop해버린다(map_screen.dart
      // 검색 바텀시트와 동일한 문제). 순서 편집 중이면 뒤로가기 한 번은 순서
      // 편집만 빠져나가고(적용된 순서는 그대로 유지), 그다음 뒤로가기에서
      // 저장 목록으로 나가게 한다.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isFolderReorderMode) {
            setState(() => _isFolderReorderMode = false);
          } else {
            setState(() => _showFolderEdit = false);
          }
        },
        child: FolderEditScreen(
          folders: folders,
          isReorderMode: _isFolderReorderMode,
          onReorderModeChanged: (value) =>
              setState(() => _isFolderReorderMode = value),
          onBack: () => setState(() => _showFolderEdit = false),
          onRenameFolder: (folder, newName) => ref
              .read(bookmarkProvider.notifier)
              .renameFolder(folder, newName),
          onDeleteFolder: (folder) =>
              ref.read(bookmarkProvider.notifier).deleteFolder(folder),
          onAddFolder: (name) =>
              ref.read(bookmarkProvider.notifier).addFolder(name),
          onReorderFolders: (newOrder) =>
              ref.read(bookmarkProvider.notifier).reorderFolders(newOrder),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(folders),
              Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: folders
                      .map(
                        (folder) => _FolderSpotList(
                          key: ValueKey(folder.id),
                          folder: folder,
                          currentPosition: _currentPosition,
                          onScrollControllerReady:
                              _registerFolderScrollController,
                          onScrollControllerDisposed:
                              _unregisterFolderScrollController,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
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
      ],
    );
  }

  Widget _buildHeader(List<BookmarkFolder> folders) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '여행지 저장 목록',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildEditButton(),
            ],
          ),
          SizedBox(height: 20.h),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.textPrimary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
            labelPadding: EdgeInsets.zero,
            labelStyle: TextStyle(fontSize: 13.sp),
            unselectedLabelStyle: TextStyle(fontSize: 13.sp),
            tabs: folders
                .map(
                  (folder) => Tab(
                    child: SizedBox(
                      width: 92.w,
                      child: Center(
                        child: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return Semantics(
      label: '저장 폴더 편집',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() => _showFolderEdit = true),
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE4E4E4), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '편집',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.edit_outlined,
                size: 16.r,
                color: AppColors.bottomNavInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 폴더 하나에 저장된 여행지 목록.
///
/// 진입 시점의 저장 목록을 스냅샷으로 고정해서 보여준다 — 카드에서 북마크를
/// 해제해도 실제 데이터([bookmarkProvider])는 바로 지워지지만, 화면에 보이는
/// 목록은 (해제된 항목이 갑자기 사라지는 게 아니라) 그대로 유지되다가 이
/// 탭을 벗어났다 다시 들어왔을 때(=이 위젯이 새로 만들어질 때)에만 지워진
/// 항목이 빠진 채로 다시 보인다.
class _FolderSpotList extends ConsumerStatefulWidget {
  const _FolderSpotList({
    super.key,
    required this.folder,
    required this.currentPosition,
    required this.onScrollControllerReady,
    required this.onScrollControllerDisposed,
  });

  final BookmarkFolder folder;

  /// 카드의 거리 표시용 현재 위치. 화면 진입 시 한 번만 구해 모든 폴더 탭이
  /// 공유하므로 null(아직 조회중/실패)일 수 있다.
  final Position? currentPosition;

  /// 이 폴더 목록의 ScrollController가 준비되면 부모에게 폴더 id로 등록해준다
  /// — 상하단 이동 버튼이 "현재 보이는 탭"의 목록을 스크롤할 때 쓴다.
  final void Function(String folderId, ScrollController controller)
  onScrollControllerReady;
  final void Function(String folderId) onScrollControllerDisposed;

  @override
  ConsumerState<_FolderSpotList> createState() => _FolderSpotListState();
}

class _FolderSpotListState extends ConsumerState<_FolderSpotList> {
  // Firestore 구독이라 진입 시점에 아직 첫 스냅샷이 안 와 있을 수 있다 —
  // null(로딩 중)과 "실제로 비어 있음"을 구분해야 해서 바로 값을 굳히지
  // 않고, 이 폴더가 처음 로드될 때까지 기다렸다가 그 한 번만 스냅샷을 찍는다.
  List<TourSpot>? _spots;
  ProviderSubscription<BookmarkState>? _loadSubscription;
  final Set<String> _unsavedContentIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.onScrollControllerReady(widget.folder.id, _scrollController);
    final current = ref.read(bookmarkProvider);
    if (current.loadedFolderIds.contains(widget.folder.id)) {
      _spots = current.spotsIn(widget.folder.id);
      return;
    }
    _loadSubscription = ref.listenManual(bookmarkProvider, (previous, next) {
      if (!next.loadedFolderIds.contains(widget.folder.id)) return;
      setState(() => _spots = next.spotsIn(widget.folder.id));
      _loadSubscription?.close();
      _loadSubscription = null;
    });
  }

  @override
  void dispose() {
    widget.onScrollControllerDisposed(widget.folder.id);
    _scrollController.dispose();
    _loadSubscription?.close();
    super.dispose();
  }

  /// 북마크 아이콘은 항상 눌러서 상태를 뒤집을 수 있다 — 해제해도 이 목록
  /// 화면(스냅샷)에서 카드 자체는 안 지워지니, 다시 눌러 재저장도 가능해야
  /// 한다. 실제로 목록에서 빠지는 건 이 폴더 탭을 벗어났다 다시 들어와서
  /// 스냅샷이 새로 찍힐 때뿐이다.
  void _handleToggleBookmark(TourSpot spot) {
    final isCurrentlySaved = !_unsavedContentIds.contains(spot.contentId);
    if (isCurrentlySaved) {
      ref.read(bookmarkProvider.notifier).unsaveSpot(spot.contentId);
      setState(() => _unsavedContentIds.add(spot.contentId));
      showAndroidToast(context, '북마크가 해제되었습니다.');
    } else {
      ref
          .read(bookmarkProvider.notifier)
          .saveSpotToFolder(widget.folder.id, spot);
      setState(() => _unsavedContentIds.remove(spot.contentId));
      showAndroidToast(context, "'${widget.folder.name}'에 추가되었습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = _spots;
    if (spots == null) {
      return const LoadingOverlay();
    }
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '저장된 여행지가 없습니다.\n여행지 상세 화면에서 북마크 아이콘을 눌러 저장해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textQuaternary),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: spots.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
      itemBuilder: (context, index) {
        final spot = spots[index];
        return _SavedSpotCard(
          spot: spot,
          currentPosition: widget.currentPosition,
          isBookmarked: !_unsavedContentIds.contains(spot.contentId),
          onToggleBookmark: () => _handleToggleBookmark(spot),
        );
      },
    );
  }
}

class _SavedSpotCard extends StatelessWidget {
  const _SavedSpotCard({
    required this.spot,
    required this.currentPosition,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  final TourSpot spot;
  final Position? currentPosition;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  /// 좌표가 없는 저장 장소나 현재 위치를 아직 못 구한 상태에서는 거리를
  /// 표시하지 않는다(map_screen.dart 검색 결과 카드와 같은 계산 방식).
  String? get _distanceLabel {
    final position = currentPosition;
    final mapX = spot.mapX;
    final mapY = spot.mapY;
    if (position == null || mapX == null || mapY == null) return null;
    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      mapY,
      mapX,
    );
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = _distanceLabel;
    final supportLabels = spot.supportedProfiles.map((p) => p.label).join(', ');
    final infoLabel = [
      spot.title,
      ?distanceLabel,
      spot.addr1,
      if (supportLabels.isNotEmpty) '$supportLabels 지원',
    ].join(', ');

    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    label: infoLabel,
                    button: true,
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            if (distanceLabel != null) ...[
                              Text(
                                distanceLabel,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Expanded(
                              child: Text(
                                spot.addr1,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (spot.supportedProfiles.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Row(
                            children: spot.supportedProfiles
                                .map(
                                  (profile) => Padding(
                                    padding: EdgeInsets.only(right: 6.w),
                                    child: Icon(
                                      profile.icon,
                                      size: 16.r,
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
                ),
                Semantics(
                  label: isBookmarked ? '북마크 해제' : '북마크 저장',
                  button: true,
                  selected: isBookmarked,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onToggleBookmark,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked
                          ? AppColors.accent
                          : AppColors.navIconInactive,
                      size: 32.r,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildThumbnailRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailRow() {
    final images = [
      spot.firstImage,
      ...spot.galleryImages,
    ].whereType<String>().toList();
    if (images.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.w;
        final cardWidth = (constraints.maxWidth - gap * 2) / 3;
        // 5:4(1.25) — 기존 115:88(1.31)보다 살짝 좁혀서, 크롭이 생기더라도
        // 위아래보다 좌우 쪽으로 더 가게 해 사진 하단의 관광공사 로고가
        // 잘릴 가능성을 줄인다.
        final cardHeight = cardWidth * 4 / 5;

        return Row(
          children: [
            for (var i = 0; i < images.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    // 관광공사 제공 사진 우하단에 로고가 찍혀있는 경우가
                    // 많아서, 크롭이 생기더라도 그 모서리는 항상 보존되도록
                    // 우하단 기준으로 자른다.
                    alignment: Alignment.bottomRight,
                    memCacheWidth: cacheDimension(
                      cardWidth,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    memCacheHeight: cacheDimension(
                      cardHeight,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    maxWidthDiskCache: cacheDimension(
                      cardWidth,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    maxHeightDiskCache: cacheDimension(
                      cardHeight,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    errorWidget: (context, url, error) =>
                        const ImagePlaceholder(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
