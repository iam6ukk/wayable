import 'package:flutter/material.dart';

const _kDialogRadius = 20.0;
const _kButtonRadius = 12.0;
const _kPrimaryColor = Color(0xFF0065F4);
const _kSecondaryColor = Color(0xFFE6E5EA);
const _kSecondaryTextColor = Color(0xFF26272B);

RoundedRectangleBorder _dialogShape() =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kDialogRadius));

RoundedRectangleBorder _buttonShape() =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kButtonRadius));

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
    builder: (dialogContext) => AlertDialog(
      shape: _dialogShape(),
      title: title == null
          ? null
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(content),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    backgroundColor: _kSecondaryColor,
                    foregroundColor: _kSecondaryTextColor,
                    shape: _buttonShape(),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: _buttonShape(),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ),
          ],
        ),
      ],
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
    builder: (dialogContext) => AlertDialog(
      shape: _dialogShape(),
      title: title == null
          ? null
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(content),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: _buttonShape(),
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );
}
