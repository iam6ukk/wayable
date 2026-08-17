import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// [SimplePopupMenu]에 넘기는 항목 하나(값 + 라벨).
class SimplePopupMenuOption<T> {
  const SimplePopupMenuOption(this.value, this.label);

  final T value;
  final String label;
}

/// 흰 배경 + faintDivider 구분선을 쓰는 단순 드롭다운 팝업 메뉴. 폴더 편집
/// 화면의 정렬 기준 메뉴와 각 폴더의 점3개(이름변경/순서편집/삭제) 메뉴가
/// 이 위젯 하나를 공유한다 — 메뉴 배경색/구분선/모서리/항목 높이 등을
/// 한 곳에서만 관리하면 된다.
class SimplePopupMenu<T> extends StatelessWidget {
  const SimplePopupMenu({
    super.key,
    required this.options,
    required this.onSelected,
    required this.child,
    this.selectedValue,
    this.onOpened,
    this.onCanceled,
    this.offset = Offset.zero,
    this.width,
    this.itemHeight,
    this.tooltip,
  });

  final List<SimplePopupMenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final Widget child;

  /// 지금 선택된 값과 일치하는 항목은 굵게 표시한다(선택 개념이 없는
  /// 메뉴라면 null로 두면 전부 동일한 굵기로 보인다).
  final T? selectedValue;
  final VoidCallback? onOpened;
  final PopupMenuCanceled? onCanceled;
  final Offset offset;
  final double? width;

  final double? itemHeight;

  /// 스크린 리더가 트리거를 읽어줄 라벨. 지정하지 않으면 Flutter 기본값(영문
  /// "Show menu")으로 읽히므로, 의미 있는 메뉴 트리거에는 항상 지정한다.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      constraints: width == null
          ? const BoxConstraints()
          : BoxConstraints.tightFor(width: width!),
      offset: offset,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      menuPadding: EdgeInsets.zero,
      color: AppColors.whiteBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
      onOpened: onOpened,
      onCanceled: onCanceled,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) PopupMenuDivider(height: 1, color: AppColors.faintDivider),
          _buildItem(options[i]),
        ],
      ],
      child: child,
    );
  }

  PopupMenuItem<T> _buildItem(SimplePopupMenuOption<T> option) {
    final isSelected = option.value == selectedValue;
    final height = itemHeight ?? 40.h;
    return PopupMenuItem<T>(
      value: option.value,
      height: height,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            option.label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
