import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 이미지가 없거나 로드에 실패했을 때 보여주는 공용 플레이스홀더 (피그마 참고).
/// 탐색 결과 카드와 상세 화면 이미지 영역에서 동일하게 사용한다.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, this.iconSize});

  /// null이면 24.r로 스케일된 기본 크기를 사용한다.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F2F2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/image_placeholder.svg',
            width: iconSize ?? 24.r,
            height: iconSize ?? 24.r,
            colorFilter: const ColorFilter.mode(Color(0xFF656565), BlendMode.srcIn),
          ),
          SizedBox(height: 8.h),
          Text(
            '이미지 준비 중',
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}
