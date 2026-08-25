import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../model/bookmark/bookmark_folder.dart';
import '../../providers/bookmark_provider.dart' show kMaxCustomFolders;
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/simple_popup_menu.dart';
import '../../widgets/toast.dart';

const _kDefaultFolderId = 'default';

const _kActionMenuWidth = 111.0;
const _kActionMenuItemHeight = 110.0 / 3;

/// 점3개 버튼 터치 영역이 실제 아이콘(24) 좌우로 넓어지는 폭. 오른쪽은 이
/// 값만큼 페이지 여백 안쪽까지, 왼쪽은 이 값만큼 텍스트 쪽 공간을 침범한다.
const _kMoreButtonTouchMargin = 25.0;

/// 위 터치 영역이 화면/리스트 오른쪽 끝에 완전히 딱 붙지 않도록 살짝
/// 띄우는 폭.
const _kMoreButtonEdgeGap = 4.0;

/// 폴더 목록 일괄 정렬 기준
/// 정렬을 고르면 순서 편집(드래그)과 동일하게 order 필드를 다시 매겨서 저장한다
/// 여행지 저장 목록 탭 순서에도 그대로 반영된다.
enum _FolderSortOption {
  newest('최신순'),
  oldest('오래된순'),
  nameAsc('이름순');

  const _FolderSortOption(this.label);
  final String label;
}

class FolderEditScreen extends StatefulWidget {
  const FolderEditScreen({
    super.key,
    required this.folders,
    required this.isReorderMode,
    required this.onReorderModeChanged,
    required this.onBack,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onAddFolder,
    required this.onReorderFolders,
  });

  final List<BookmarkFolder> folders;

  /// 순서 편집 모드 여부. 뒤로가기를 눌렀을 때 이 화면 자체가 아니라
  /// 저장 목록 화면(SavedListScreen)까지 한 번에 나갈지 판단해야 해서, 이
  /// 위젯의 로컬 상태가 아니라 부모가 들고 있는 값을 그대로 받아쓴다.
  final bool isReorderMode;
  final ValueChanged<bool> onReorderModeChanged;
  final VoidCallback onBack;
  final void Function(BookmarkFolder folder, String newName) onRenameFolder;
  final void Function(BookmarkFolder folder) onDeleteFolder;
  final void Function(String name) onAddFolder;
  final void Function(List<BookmarkFolder> newOrder) onReorderFolders;

  @override
  State<FolderEditScreen> createState() => _FolderEditScreenState();
}

class _FolderEditScreenState extends State<FolderEditScreen> {
  /// 이번에 이 화면을 여는 동안 고른 정렬 기준(고르기 전엔 null). 실제
  /// 순서는 항상 폴더의 order 필드가 기준이라, 이 값은 정렬 버튼에 지금
  /// 선택된 기준을 보여주기 위한 화면 전용 상태일 뿐이다.
  _FolderSortOption? _sortOption;

  /// 정렬 기준 팝업 메뉴가 열려 있는 동안 화살표 아이콘을 위로 뒤집어
  /// 보여주기 위한 화면 전용 상태.
  bool _isSortMenuOpen = false;

  /// 기본 폴더는 이름 변경/삭제/순서 변경이 안 되는, 항상 맨 위에 고정된
  /// 폴더다. 정렬·순서 변경은 전부 이 기본 폴더를 뺀 나머지(커스텀 폴더)
  /// 안에서만 이뤄지고, 반영할 때 항상 기본 폴더를 맨 앞에 다시 붙인다.
  BookmarkFolder? get _defaultFolder {
    for (final folder in widget.folders) {
      if (folder.id == _kDefaultFolderId) return folder;
    }
    return null;
  }

  List<BookmarkFolder> get _customFolders =>
      widget.folders.where((f) => f.id != _kDefaultFolderId).toList();

  void _applyCustomOrder(List<BookmarkFolder> customOrder) {
    widget.onReorderFolders([?_defaultFolder, ...customOrder]);
  }

  void _handleSortSelected(_FolderSortOption option) {
    final sorted = _customFolders;
    switch (option) {
      case _FolderSortOption.newest:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _FolderSortOption.oldest:
        sorted.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
      case _FolderSortOption.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() {
      _sortOption = option;
      _isSortMenuOpen = false;
    });
    _applyCustomOrder(sorted);
  }

  Future<void> _handleMenuSelected(
    BuildContext context,
    BookmarkFolder folder,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        final newName = await showFolderNameInputDialog(
          context,
          title: '폴더 이름 변경',
          primaryLabel: '변경하기',
          initialName: folder.name,
        );
        if (newName != null) widget.onRenameFolder(folder, newName);
      case 'reorder':
        widget.onReorderModeChanged(true);
      case 'delete':
        final confirmed = await showTwoButtonDialog(
          context,
          title: '폴더를 삭제하시겠습니까?',
          content: '폴더에 저장된 여행지도 함께 삭제됩니다.\n삭제 후에는 복구할 수 없습니다.',
          primaryLabel: '삭제하기',
          secondaryLabel: '취소',
        );
        if (confirmed == true) widget.onDeleteFolder(folder);
    }
  }

  Future<void> _handleAddFolder(BuildContext context) async {
    if (_customFolders.length >= kMaxCustomFolders) {
      showAndroidToast(context, '폴더는 최대 $kMaxCustomFolders개까지 만들 수 있어요.');
      return;
    }
    final name = await showFolderNameInputDialog(
      context,
      title: '새 폴더 추가',
      primaryLabel: '추가하기',
    );
    if (name != null) widget.onAddFolder(name);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final reordered = _customFolders;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    _applyCustomOrder(reordered);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(
          child: widget.isReorderMode
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 기본 폴더는 순서 변경 대상이 아니라 항상 맨 위에 고정
                    // 노출한다 — 드래그 핸들도 없어서 아예 집을 수가 없다.
                    if (_defaultFolder case final defaultFolder?)
                      _buildPinnedDefaultRow(defaultFolder),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.zero,
                        buildDefaultDragHandles: false,
                        itemCount: _customFolders.length,
                        onReorderItem: _handleReorder,
                        // 드래그 중인 항목은 기본적으로 Material 3의
                        // surfaceTint가 덧입혀져서 살짝 분홍빛으로 보인다 —
                        // 바텀시트와 동일한 배경색을 명시해서 그 틴트를
                        // 덮어쓴다.
                        proxyDecorator: (child, index, animation) => Material(
                          color: AppColors.bottomSheetBackground,
                          child: child,
                        ),
                        itemBuilder: (context, index) =>
                            _buildReorderRow(_customFolders[index], index),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: widget.folders.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.faintDivider,
                  ),
                  itemBuilder: (context, index) =>
                      _buildFolderRow(context, widget.folders[index]),
                ),
        ),
        if (!widget.isReorderMode)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 16.h, 0, 24.h),
            child: Center(child: _buildNewFolderButton(context)),
          ),
      ],
    );
  }

  // 여행지 저장 목록 화면(SavedListScreen)의 헤더와 좌우/상단 여백을 맞춘다
  // (L/R 16.w, 상단 24.h) — 이 화면은 그 화면의 '편집'을 눌러 콘텐츠만
  // 갈아끼워진 것이라, 전환 시 제목 위치가 위아래로 튀어 보이면 안 된다.
  // IconButton의 기본 48x48 탭 영역을 그대로 쓰면 그 안에서 세로 중앙 정렬된
  // 제목까지 아래로 밀려서 저장목록 화면의 제목 위치와 어긋나므로, 아이콘
  // 크기만큼만 차지하는 얇은 탭 영역으로 대신한다.
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBackButton(),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '폴더 편집',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '저장된 폴더 (${widget.folders.length})',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              _buildSortButton(),
            ],
          ),
        ],
      ),
    );
  }

  // 순서 편집 모드에서는 뒤로가기가 바로 저장 목록으로 나가지 않고, 순서
  // 편집만 먼저 종료해서(적용된 순서는 유지) 기본 폴더 편집 화면으로
  // 돌아간다. 그 상태에서 한 번 더 누르면 그때 저장 목록으로 나간다.
  Widget _buildBackButton() {
    return Semantics(
      label: '뒤로가기',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: () {
          if (widget.isReorderMode) {
            widget.onReorderModeChanged(false);
          } else {
            widget.onBack();
          }
        },
        child: Padding(
          padding: EdgeInsets.only(top: 4.r, right: 4.r, bottom: 4.r),
          // arrow_back_ios_new 글리프 자체가 24x24 박스 안에서 왼쪽에 여백을
          // 두고 그려져 있어서, 그대로 두면 화살표가 아래 '저장된 폴더'
          // 텍스트보다 화면 좌측 여백(16.w) 안쪽으로 더 들어가 보인다 — 그
          // 여백만큼 왼쪽으로 당겨서 좌측 기준선을 맞춘다.
          child: Transform.translate(
            offset: Offset(-4.r, 0),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 20.r,
              color: AppColors.bottomNavActive,
            ),
          ),
        ),
      ),
    );
  }

  // 피그마 리뉴얼: 흰 배경/테두리/그림자가 있던 알약 버튼을, 배경 없는
  // 텍스트+화살표만으로 단순화했다. 라벨은 선택한 정렬 기준으로 바뀌지
  // 않고 항상 '정렬 기준'을 보여주고(고른 기준은 메뉴 안에서 굵게 표시),
  // 메뉴가 열려 있는 동안엔 세모 화살표가 위를 향하도록 뒤집는다.
  Widget _buildSortButton() {
    return SimplePopupMenu<_FolderSortOption>(
      tooltip: '정렬 기준 선택',
      options: [
        for (final option in _FolderSortOption.values)
          SimplePopupMenuOption(option, option.label),
      ],
      selectedValue: _sortOption,
      onOpened: () => setState(() => _isSortMenuOpen = true),
      onCanceled: () => setState(() => _isSortMenuOpen = false),
      onSelected: _handleSortSelected,
      // 점3개 메뉴와 동일한 이유로, 메뉴가 버튼과 겹치지 않고 버튼 바로
      // 아래에서 시작하도록 버튼 높이만큼 내린다.
      offset: Offset(0, 24.h),
      width: _kActionMenuWidth.w,
      itemHeight: _kActionMenuItemHeight.h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '정렬 기준',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          Icon(
            _isSortMenuOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 24.r,
            color: AppColors.bottomNavActive,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(BuildContext context, BookmarkFolder folder) {
    // 기본 폴더는 이름 변경/순서 편집/삭제가 전부 불가능해서 점3개 메뉴
    // 자체를 보여주지 않는다.
    final isDefault = folder.id == _kDefaultFolderId;
    return SizedBox(
      height: 61.h,
      // 점3개 버튼의 터치 영역을 리스트 좌우 여백(32) 안쪽으로도 넓히려면
      // 그 버튼만 이 여백 밖으로 뺄 수 있어야 해서, 기존처럼 Row 전체를
      // symmetric padding으로 감싸지 않고 좌우 여백을 각 끝에서 개별적으로
      // 넣는다.
      child: Row(
        children: [
          SizedBox(width: 32.w),
          ExcludeSemantics(
            child: Icon(
              Icons.folder_outlined,
              size: 20.r,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 17.w),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
            ),
          ),
          if (!isDefault)
            SimplePopupMenu<String>(
              tooltip: '${folder.name} 폴더 관리',
              // 정렬 기준 메뉴와 크기를 맞춘다(피그마상 두 메뉴 모두
              // 111×110, 3항목 동일 디자인).
              width: _kActionMenuWidth.w,
              itemHeight: _kActionMenuItemHeight.h,
              // PopupMenuButton은 버튼이 화면 오른쪽에 가까우면 메뉴 오른쪽
              // 끝을 버튼 오른쪽 끝에 자동으로 맞춰서 왼쪽으로 펼쳐준다. 단,
              // 그 "버튼 오른쪽 끝" 기준은 child(터치 영역) 박스의 오른쪽
              // 끝이지 실제로 보이는 아이콘의 오른쪽 끝이 아니다. 지금은
              // 터치 영역이 아이콘보다 오른쪽으로 _kMoreButtonTouchMargin만큼
              // 더 넓으므로(아래 child 참고) 그 차이만큼 offset.dx를 왼쪽으로
              // 당겨서 기준점을 실제 아이콘 오른쪽 끝으로 되돌린다.
              offset: Offset(
                -_kMoreButtonTouchMargin.w,
                (61.h + 24.r) / 2,
              ),
              options: const [
                SimplePopupMenuOption('rename', '이름 변경'),
                SimplePopupMenuOption('reorder', '순서 편집'),
                SimplePopupMenuOption('delete', '폴더 삭제'),
              ],
              onSelected: (action) =>
                  _handleMenuSelected(context, folder, action),
              // PopupMenuButton의 탭 영역은 child의 렌더 크기 그대로라,
              // 아이콘 자체가 24라 실기기에서 터치가 잘 안 먹힌다는 제보가
              // 있었다. 오른쪽은 원래 페이지 여백(32) 중 _kMoreButtonTouchMargin
              // 만큼만 침범해서 아이콘을 그 안쪽에 Align으로 고정하고(그래야
              // SizedBox의 tight 제약이 아이콘을 억지로 늘리지 않는다), 왼쪽도
              // 텍스트 쪽으로 같은 폭만큼 넓힌다.
              child: SizedBox(
                height: 61.h,
                width: 24.w + _kMoreButtonTouchMargin.w * 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 24.w + _kMoreButtonTouchMargin.w,
                    child: Padding(
                      padding: EdgeInsets.only(right: _kMoreButtonTouchMargin.w),
                      child: Icon(
                        Icons.more_vert,
                        size: 24.r,
                        color: AppColors.bottomNavActive,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isDefault)
            // 터치 영역(오른쪽 끝)이 화면 끝에 딱 붙어서 오른쪽 여백만
            // 유독 커 보인다는 피드백이 있었다. 실제로 화면 끝과 살짝
            // 떨어지도록 뒤에 여백을 추가한다.
            SizedBox(width: _kMoreButtonEdgeGap.w)
          else
            SizedBox(width: 32.w),
        ],
      ),
    );
  }

  /// 순서 편집 모드에서 기본 폴더를 맨 위에 고정 노출하는 행. 드래그 핸들이
  /// 없어서 아예 집을 수 없다.
  Widget _buildPinnedDefaultRow(BookmarkFolder folder) {
    return Container(
      height: 61.h,
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.faintDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.folder_outlined,
              size: 20.r,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 17.w),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderRow(BookmarkFolder folder, int index) {
    final isLast = index == _customFolders.length - 1;
    return Container(
      key: ValueKey(folder.id),
      height: 61.h,
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: AppColors.faintDivider, width: 1),
              ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.folder_outlined,
              size: 20.r,
              color: AppColors.bottomNavActive,
            ),
          ),
          SizedBox(width: 17.w),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
            ),
          ),
          // 드래그 시작 판정 영역을 아이콘 크기(24)가 아니라 리스트 행
          // 높이(61)만큼 키우고 너비도 살짝 넓힌다. 아이콘이 원래 있던
          // 위치(끝에서 딱 붙은 자리)는 그대로 유지해야 하므로 커진 영역
          // 안에서 오른쪽 끝으로 정렬한다(늘어난 여유 공간은 왼쪽으로만
          // 붙는다) — 점3개 버튼 터치 영역을 넓힐 때와 같은 방식.
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              height: 61.h,
              width: 40.w,
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: '${folder.name} 순서 이동 핸들',
                  child: Icon(
                    Icons.dehaze,
                    size: 24.r,
                    color: AppColors.bottomNavActive,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewFolderButton(BuildContext context) {
    return SizedBox(
      width: 106.w,
      height: 38.h,
      child: ElevatedButton.icon(
        onPressed: () => _handleAddFolder(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.popupMenuBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(51.r),
          ),
        ),
        icon: Icon(Icons.create_new_folder_outlined, size: 17.r),
        label: Text(
          '새 폴더',
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
