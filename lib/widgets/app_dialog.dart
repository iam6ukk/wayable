import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// 폴더 삭제 확인 다이얼로그 기준 노드(Figma 393px 프레임, 앱 전역 ScreenUtil
/// 기준 프레임과 동일)에서 측정한 좌우 마진 평균값. 카드 너비를 고정하지
/// 않고 이 마진만큼만 비워두는 방식이라 화면 폭에 비례해 자동으로 커진다.
const _kOuterMarginPx = 40.5;
const _kDialogRadius = 24.0;
const _kFooterHeight = 63.0;

RoundedRectangleBorder _dialogShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(_kDialogRadius.r),
);

TextStyle _bodyTextStyle(FontWeight weight) => TextStyle(
  fontSize: 14.sp,
  fontWeight: weight,
  color: AppColors.textPrimary,
  height: 1.5,
);

TextStyle _actionTextStyle(Color color) =>
    TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: color);

/// title이 있으면 title(세미볼드)/content(라이트)로 구분되고, title 없이
/// content 하나만 쓰는 다이얼로그(로그인 유도, 안내, 원버튼 등)는 세미볼드로
/// 통일한다.
Widget _dialogBody({required String? title, required String content}) {
  final hasTitle = title != null;
  return Padding(
    padding: EdgeInsets.fromLTRB(30.w, 28.h, 30.w, 24.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTitle) ...[
          Text(title, style: _bodyTextStyle(FontWeight.w600)),
          SizedBox(height: 4.h),
        ],
        Text(
          content,
          style: _bodyTextStyle(hasTitle ? FontWeight.w300 : FontWeight.w600),
        ),
      ],
    ),
  );
}

Widget _footerButton({
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _kFooterHeight.h,
        child: Center(child: Text(label, style: _actionTextStyle(color))),
      ),
    ),
  );
}

/// 버튼 2개(보조/주 액션)짜리 컨펌 다이얼로그. 좌우로 배치되며 좌측이 보조
/// 액션, 우측이 주 액션이다. 주 액션을 누르면 true, 보조 액션이나 다이얼로그
/// 바깥을 눌러 닫으면 false/null을 반환한다.
Future<bool?> showTwoButtonDialog(
  BuildContext context, {
  String? title,
  required String content,
  required String primaryLabel,
  required String secondaryLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.barrierBackground,
    builder: (dialogContext) => Dialog(
      shape: _dialogShape(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: _kOuterMarginPx.w,
        vertical: 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogBody(title: title, content: content),
          Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
          IntrinsicHeight(
            child: Row(
              children: [
                _footerButton(
                  label: secondaryLabel,
                  color: AppColors.textPrimary,
                  onTap: () => Navigator.of(dialogContext).pop(false),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.faintDivider,
                ),
                _footerButton(
                  label: primaryLabel,
                  color: AppColors.primary,
                  onTap: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 확인 버튼 1개짜리 안내 다이얼로그.
Future<void> showInfoDialog(
  BuildContext context, {
  String? title,
  required String content,
  String confirmLabel = '확인',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.barrierBackground,
    builder: (dialogContext) => Dialog(
      shape: _dialogShape(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: _kOuterMarginPx.w,
        vertical: 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogBody(title: title, content: content),
          Divider(height: 1, thickness: 1, color: AppColors.faintDivider),
          InkWell(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: SizedBox(
              width: double.infinity,
              height: _kFooterHeight.h,
              child: Center(
                child: Text(
                  confirmLabel,
                  style: _actionTextStyle(AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
