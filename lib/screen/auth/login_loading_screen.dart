import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wayable/widgets/loading_animation.dart';

/// 카카오/구글 로그인 요청을 보낸 뒤 홈 화면으로 넘어가기 전까지 보여주는 로딩 화면
class LoginLoadingScreen extends StatelessWidget {
  const LoginLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF363636).withValues(alpha: 0.3),
          ),
          Positioned(
            top: 300.h + 120.r - (67.5.r / 2),
            left: 0,
            right: 0,
            child: const Center(child: LoadingAnimation()),
          ),
        ],
      ),
    );
  }
}
