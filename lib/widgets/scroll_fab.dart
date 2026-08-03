import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _kScrollFabBg = Color(0xFFF0F4F8);
const _kScrollFabIconColor = Color(0xFF767676);

/// 목록 화면 우측 하단에 떠서 맨 위/맨 아래로 스크롤 이동시키는 버튼.
/// 맞춤 여행지 탐색 화면에서 쓰던 걸 다른 목록 화면에서도 재사용할 수 있도록 분리.
class ScrollFab extends StatelessWidget {
  const ScrollFab({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kScrollFabBg,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 29.3.r,
          height: 29.3.r,
          child: Icon(icon, size: 15.r, color: _kScrollFabIconColor),
        ),
      ),
    );
  }
}
