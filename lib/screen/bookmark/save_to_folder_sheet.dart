import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../model/bookmark/bookmark_folder.dart';
import '../../model/tour/tour_spot.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/toast.dart';

/// 폴더 한 줄의 고정 높이(피그마 기준 "기본 폴더"~"폴더 A" 행 간격 47px).
/// 4줄까지는 이 높이만큼 시트가 늘어나고,
/// 5개 이상부터는 늘어나지 않고 이 높이(4줄치) 안에서 스크롤된다.
const _kFolderRowHeight = 47.0;
const _kMaxVisibleFolderRows = 4;

/// '새로 만들기' 선택을 실제 폴더 id와 구분하기 위한 내부 sentinel 값.
const _kCreateNewFolderValue = '__create_new_folder__';

/// 여행지 상세화면 북마크 아이콘에서 호출한다.
/// 폴더 선택 바텀시트를 띄우고 '확인'을 누르면 선택한 폴더에 저장 + 안내 토스트를 보여준다.
/// '새로 만들기'를 누르면 바텀시트를 닫고 새 폴더 추가 다이얼로그를 띄운 뒤,
/// 추가되면 그 폴더가 선택된 채로 바텀시트를 다시 띄운다.
Future<void> showSaveToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  TourSpot spot, {
  String? preselectedFolderId,
}) async {
  final bookmarks = ref.read(bookmarkProvider);
  final preselectedId =
      preselectedFolderId ??
      bookmarks.folderIdContaining(spot.contentId) ??
      (bookmarks.folders.isEmpty ? null : bookmarks.folders.first.id);

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaveToFolderSheet(
      folders: bookmarks.folders,
      initialSelectedId: preselectedId,
    ),
  );

  if (result == null || !context.mounted) return;

  if (result == _kCreateNewFolderValue) {
    final customFolderCount = ref
        .read(bookmarkProvider)
        .folders
        .where((f) => f.id != 'default')
        .length;
    if (customFolderCount >= kMaxCustomFolders) {
      // 폴더 생성 개수 제한
      showAndroidToast(context, '폴더는 최대 $kMaxCustomFolders개까지 만들 수 있어요.');
      return;
    }
    final name = await showFolderNameInputDialog(
      context,
      title: '새 폴더 추가',
      primaryLabel: '추가하기',
    );
    if (name == null || !context.mounted) return;
    final newFolder = await ref.read(bookmarkProvider.notifier).addFolder(name);
    if (!context.mounted) return;
    await showSaveToFolderSheet(
      context,
      ref,
      spot,
      preselectedFolderId: newFolder.id,
    );
    return;
  }

  final folder = ref
      .read(bookmarkProvider)
      .folders
      .firstWhere((f) => f.id == result);
  ref.read(bookmarkProvider.notifier).saveSpotToFolder(folder.id, spot);
  showAndroidToast(context, "'${folder.name}'에 추가되었습니다.");
}

class _SaveToFolderSheet extends StatefulWidget {
  const _SaveToFolderSheet({
    required this.folders,
    required this.initialSelectedId,
  });

  final List<BookmarkFolder> folders;
  final String? initialSelectedId;

  @override
  State<_SaveToFolderSheet> createState() => _SaveToFolderSheetState();
}

class _SaveToFolderSheetState extends State<_SaveToFolderSheet> {
  late String? _selectedId = widget.initialSelectedId;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 새 폴더를 만들고 이 시트가 다시 뜰 때처럼, 미리 선택된 폴더가 스크롤
    // 영역 밖에 있으면 그 위치까지 스크롤해서 보여준다
    // 사용자에게 스크롤이 가능하다는 것을 보여주기 위함
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final selectedId = _selectedId;
    if (selectedId == null || !_scrollController.hasClients) return;
    final index = widget.folders.indexWhere((f) => f.id == selectedId);
    if (index < 0) return;
    final targetOffset = (_kFolderRowHeight.h * index).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 폴더 4개까지는 목록 높이가 그대로 늘어나서 시트도 같이 커지고,
    // 5개부터는 4줄 높이로 고정한 채 그 안에서 스크롤된다.
    final visibleRows = widget.folders.length.clamp(0, _kMaxVisibleFolderRows);
    final listHeight = _kFolderRowHeight.h * visibleRows;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bottomSheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.4.r)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          SizedBox(
            height: listHeight,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 47.w),
              children: widget.folders.map(_buildFolderRow).toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(38.w, 12.h, 38.w, 20.h),
            child: _buildConfirmButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '새 폴더 만들기',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(_kCreateNewFolderValue),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.create_new_folder_outlined,
                        size: 20.r,
                        color: AppColors.bottomNavActive,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '새로 만들기',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(
            '폴더 선택',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: '닫기',
                button: true,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    size: 24.r,
                    color: AppColors.navIconInactive,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(BookmarkFolder folder) {
    final selected = folder.id == _selectedId;
    return SizedBox(
      height: _kFolderRowHeight.h,
      child: Semantics(
        label: folder.name,
        button: true,
        selected: selected,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => setState(() => _selectedId = folder.id),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildSelectionCircle(selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCircle(bool selected) {
    return Container(
      width: 20.r,
      height: 20.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: selected ? null : Border.all(color: AppColors.faintDivider),
      ),
      child: selected
          ? Icon(Icons.check, size: 17.r, color: Colors.white)
          : null,
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 43.h,
      child: ElevatedButton(
        onPressed: _selectedId == null
            ? null
            : () => Navigator.of(context).pop(_selectedId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.faintDivider,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21.5.r),
          ),
        ),
        child: Text('확인', style: TextStyle(fontSize: 13.sp)),
      ),
    );
  }
}
