import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../model/bookmark/bookmark_folder.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';

const _kMenuBackground = Color(0xFFEEEEEE);
const _kNewFolderButtonBg = Color(0xFFD9D9D9);
const _kTitleColor = Color(0xFF060606);

/// 저장목록 폴더 편집 콘텐츠. 저장목록 화면(SavedListScreen) 안에서 '편집'을
/// 누르면 콘텐츠 영역만 이 화면으로 갈아끼워진다 — 별도 라우트로 push되는
/// 화면이 아니라서 상단 배너/하단 탭바를 다시 그리지 않고, 폴더 목록도 직접
/// 들고 있지 않고 부모(SavedListScreen)가 관리하는 목록/콜백을 그대로 받는다.
///
/// 평소엔 각 행의 점3개 버튼을 누르면 그 버튼 바로 아래에 이름 변경/순서
/// 편집/폴더 삭제 메뉴가 뜬다. 그중 '순서 편집'을 고르면 이 화면 자체가
/// (별도 페이지 push 없이) 순서 편집 모드로 바뀐다 — 헤더가 '< 순서 편집'로
/// 바뀌고 점3개 버튼 자리가 드래그 핸들(햄버거 아이콘)로 바뀌어서, 그 아이콘을
/// 누른 채로 위/아래로 드래그해 순서를 정하고 손을 떼면 바로 반영된다.
/// 뒤로가기를 누르면 평소 화면으로 돌아가되, 그 사이 바뀐 순서는 그대로
/// 유지된다(순서는 SavedListScreen이 들고 있는 bookmarkProvider 상태라서
/// 이 화면의 모드와 무관하게 항상 최신 값을 보여준다).
class FolderEditScreen extends StatefulWidget {
  const FolderEditScreen({
    super.key,
    required this.folders,
    required this.onBack,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onAddFolder,
    required this.onReorderFolders,
  });

  final List<BookmarkFolder> folders;
  final VoidCallback onBack;
  final void Function(BookmarkFolder folder, String newName) onRenameFolder;
  final void Function(BookmarkFolder folder) onDeleteFolder;
  final void Function(String name) onAddFolder;
  final void Function(List<BookmarkFolder> newOrder) onReorderFolders;

  @override
  State<FolderEditScreen> createState() => _FolderEditScreenState();
}

class _FolderEditScreenState extends State<FolderEditScreen> {
  bool _isReorderMode = false;

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
        setState(() => _isReorderMode = true);
      case 'delete':
        final confirmed = await showTwoButtonDialog(
          context,
          title: '폴더를 삭제할까요?',
          content: '이 폴더에 저장된 여행지도 함께 삭제돼요.\n삭제 후에는 복구할 수 없어요.',
          primaryLabel: '삭제하기',
          secondaryLabel: '아니오',
        );
        if (confirmed == true) widget.onDeleteFolder(folder);
    }
  }

  Future<void> _handleAddFolder(BuildContext context) async {
    final name = await showFolderNameInputDialog(
      context,
      title: '새 폴더 추가',
      primaryLabel: '추가하기',
    );
    if (name != null) widget.onAddFolder(name);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final reordered = [...widget.folders];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    widget.onReorderFolders(reordered);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(
          child: _isReorderMode
              ? ReorderableListView.builder(
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  itemCount: widget.folders.length,
                  onReorderItem: _handleReorder,
                  itemBuilder: (context, index) =>
                      _buildReorderRow(widget.folders[index], index),
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
        if (!_isReorderMode)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 16.h, 0, 24.h),
            child: Center(child: _buildNewFolderButton(context)),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 24.h),
      child: Row(
        children: [
          IconButton(
            onPressed: _isReorderMode
                ? () => setState(() => _isReorderMode = false)
                : widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: _kTitleColor),
          ),
          Text(
            _isReorderMode ? '순서 편집' : '폴더 편집',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(BuildContext context, BookmarkFolder folder) {
    return SizedBox(
      height: 61.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 24.r,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: 17.w),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
              ),
            ),
            PopupMenuButton<String>(
              // icon 대신 child를 쓰면 기본 IconButton의 48x48 최소 탭 영역이
              // 붙지 않아, 왼쪽 폴더 아이콘과 동일하게 24px 크기 그대로
              // 오른쪽 여백이 잡힌다(icon을 쓰면 보이지 않는 여백이 더해져
              // 좌우 마진이 안 맞아 보였다).
              constraints: BoxConstraints.tightFor(width: 121.w),
              // offset의 기본값(Offset.zero)은 메뉴가 버튼(점3개 아이콘)과
              // 같은 위치에서부터 겹쳐 자라나서, 메뉴가 버튼 자체를 덮어버린다.
              // 버튼 높이(24)만큼 아래로 내려서 버튼 바로 아래에서 메뉴가
              // 시작하도록 한다.
              offset: Offset(0, 24.r),
              popUpAnimationStyle: AnimationStyle.noAnimation,
              // 메뉴 전체를 감싸는 기본 padding(수직 8)이 있어서, 항목 사이는
              // 구분선 1px뿐인데 첫/마지막 항목의 위/아래에만 여백이 더 생겨
              // 보였다 — 0으로 없애서 세 항목의 위아래 여백을 동일하게 만든다.
              menuPadding: EdgeInsets.zero,
              color: _kMenuBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
              onSelected: (action) =>
                  _handleMenuSelected(context, folder, action),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                _menuItem('rename', '이름 변경'),
                PopupMenuDivider(height: 1, color: AppColors.faintDivider),
                _menuItem('reorder', '순서 편집'),
                PopupMenuDivider(height: 1, color: AppColors.faintDivider),
                _menuItem('delete', '폴더 삭제'),
              ],
              child: Icon(
                Icons.more_vert,
                size: 24.r,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderRow(BookmarkFolder folder, int index) {
    final isLast = index == widget.folders.length - 1;
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
          Icon(Icons.folder_outlined, size: 24.r, color: AppColors.textPrimary),
          SizedBox(width: 17.w),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.dehaze, size: 24.r, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      // PopupMenuItem.height는 최소 높이일 뿐이고 기본값(48)이 더 크면 그게
      // 이겨버리므로, height도 40으로 낮추고 SizedBox로 실제 높이를 한 번 더
      // 고정해 세 항목 모두 정확히 같은 높이·같은 상하 여백을 갖도록 한다.
      height: 40.h,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 40.h,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewFolderButton(BuildContext context) {
    return SizedBox(
      width: 116.w,
      height: 41.h,
      child: ElevatedButton.icon(
        onPressed: () => _handleAddFolder(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kNewFolderButtonBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(51.r),
          ),
        ),
        icon: Icon(Icons.create_new_folder_outlined, size: 18.r),
        label: Text('새 폴더', style: TextStyle(fontSize: 13.sp)),
      ),
    );
  }
}
