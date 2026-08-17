import 'package:flutter/material.dart';
import 'loading_animation.dart';

/// 화면(또는 그 화면이 차지하는 영역) 전체를 어둡게 깔고 그 위에
/// [LoadingAnimation]을 띄우는 오버레이. map_screen에서 쓰던 방식을
/// 다른 화면에서도 재사용하기 위해 뺐다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF363636).withValues(alpha: 0.3)),
        const Center(child: LoadingAnimation()),
      ],
    );
  }
}
