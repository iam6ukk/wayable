import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// 상단 로고 배너. 화면 최상단에 고정으로 붙는 공통 헤더.
class TopLogoBanner extends StatelessWidget {
  const TopLogoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: kToolbarHeight,
        child: Center(
          child: Image.asset(
            'assets/images/common/wayable.png',
            height: 28.h,
          ),
        ),
      ),
    );
  }
}
