import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 67.5.r,
      height: 67.5.r,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11.25.r),
      ),
      alignment: Alignment.center,
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: 50.r,
        height: 50.r,
        repeat: true,
      ),
    );
  }
}
