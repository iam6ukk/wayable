import 'package:flutter/material.dart';

const _kBannerColor = Color(0xFFD8EDFF);

/// 상단 로고 배너. 화면 최상단에 고정으로 붙는 공통 헤더.
class TopLogoBanner extends StatelessWidget {
  const TopLogoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // 상태 바 영역은 배경색만 이어지도록 상단 인셋만큼 추가 패딩을 주고,
    // 실제 배너 영역은 하단 탭 바와 동일한 표준 높이(56dp)로 맞춘다.
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: _kBannerColor,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: kToolbarHeight,
        child: Center(
          child: Image.asset('assets/images/wayable.png', height: 28),
        ),
      ),
    );
  }
}
