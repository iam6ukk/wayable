import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 필터 선택 등에서 쓰는 화살표 아이콘. pointsUp에 따라 위/아래 방향 이미지를 보여준다.
class ChevronIcon extends StatelessWidget {
  const ChevronIcon({super.key, required this.pointsUp, required this.color});

  final bool pointsUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      pointsUp
          ? 'assets/images/common/up_arrow.png'
          : 'assets/images/common/down_arrow.png',
      width: 11.r,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}
