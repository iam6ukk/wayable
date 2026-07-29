import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../model/accessibility/accessibility_profile.dart';
import '../../model/bookmark/bookmark_folder.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/toast.dart';
import '../search/spot_detail_screen.dart';
import 'folder_edit_screen.dart';

const _kTabUnselectedColor = Color(0xFFA0A0A0);
const _kSpotTextColor = Color(0xFF1C1C1C);
const _kEditButtonColor = Color(0xFF7D7D7D);

/// 여행지 저장 목록 화면. 폴더별로 탭을 두고 폴더 안에 저장된 여행지를
/// 보여준다. 폴더/저장된 여행지 모두 [bookmarkProvider]가 들고 있어서, 여행지
/// 상세화면의 저장 바텀시트나 폴더 편집 화면에서 바꾼 내용이 바로 반영된다.
///
/// '편집'을 누르면 페이지 전환(Navigator.push) 대신 이 화면의 콘텐츠 영역만
/// 폴더 편집 화면으로 갈아끼운다 — 상단 배너/하단 탭바는 이 화면을 감싸는
/// MainShell이 항상 그리고 있으므로 다시 그릴 필요가 없다.
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
  int _lastFolderCount = 0;

  @override
  void initState() {
    super.initState();
    _lastFolderCount = ref.read(bookmarkProvider).folders.length;
    _tabController = TabController(length: _lastFolderCount, vsync: this);
  }

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
      return FolderEditScreen(
        folders: folders,
        onBack: () => setState(() => _showFolderEdit = false),
        onRenameFolder: (folder, newName) =>
            ref.read(bookmarkProvider.notifier).renameFolder(folder, newName),
        onDeleteFolder: (folder) =>
            ref.read(bookmarkProvider.notifier).deleteFolder(folder),
        onAddFolder: (name) =>
            ref.read(bookmarkProvider.notifier).addFolder(name),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(folders),
        Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: folders
                .map((folder) => _FolderSpotList(folder: folder))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<BookmarkFolder> folders) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '여행지 저장 목록',
                  style: TextStyle(
                    fontSize: 20.sp,
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
            unselectedLabelColor: _kTabUnselectedColor,
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
    return InkWell(
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
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF3C3C3C)),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.edit_outlined, size: 16.r, color: _kEditButtonColor),
          ],
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
  const _FolderSpotList({required this.folder});

  final BookmarkFolder folder;

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

  @override
  void initState() {
    super.initState();
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
      return const Center(child: CircularProgressIndicator());
    }
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            '저장된 여행지가 없어요.\n여행지 상세화면에서 북마크 아이콘을 눌러 저장해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textQuaternary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: spots.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
      itemBuilder: (context, index) {
        final spot = spots[index];
        return _SavedSpotCard(
          spot: spot,
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
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  final TourSpot spot;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: _kSpotTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Text(
                            '1.5km',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: _kSpotTextColor,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              spot.addr1,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: _kSpotTextColor,
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
                                    color: _kEditButtonColor,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onToggleBookmark,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked
                        ? AppColors.accent
                        : AppColors.boldDivider,
                    size: 24.r,
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
    // 썸네일 + detailImage2로 받아온 추가 이미지까지 최대 3장
    final images = [
      spot.firstImage,
      ...spot.galleryImages,
    ].whereType<String>().toList();

    return Row(
      children: List.generate(3, (index) {
        final imageUrl = index < images.length ? images[index] : null;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8.w),
            child: AspectRatio(
              aspectRatio: 115 / 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: imageUrl == null
                    ? const ImagePlaceholder()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ImagePlaceholder(),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
