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
        // kToolbarHeight(Material 기본 56dp)는 뷰포트 스케일과 무관한
        // 고정값이라, 로고(28.h)처럼 세로 스케일을 따라 커지는 콘텐츠와
        // 같이 두면 화면 세로 스케일이 큰 기기(태블릿)에서는 로고가 이
        // 고정 높이에 거의 꽉 차 위아래 여백이 없어 보이고, 스케일이
        // 1에 가까운 기기(폰)에서는 여백이 넉넉해 보여 기기마다 배너
        // 안쪽 여백이 달라 보였다. 배너 높이도 같은 축(.h)으로 스케일해야
        // 로고와의 여백 비율이 기기와 무관하게 항상 동일하게 유지된다.
        height: kToolbarHeight.h,
        child: Center(
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/images/common/wayable.png',
              height: 28.h,
            ),
          ),
        ),
      ),
    );
  }
}
