import 'package:flutter/material.dart';

/// 앱 전역에서 재사용하는 색상 상수 모음.
class AppColors {
  AppColors._();

  // 메인 컬러: 기본 버튼/핵심 액션, 선택 배경/안내 영역, 추천·저장·강조 정보
  static const primary = Color(0xFF2563EB);
  static const bannerBackground = Color(0xFFEAF4FE);
  static const accent = Color(0xFFFFD166);

  // 텍스트 강조 단계: Primary > Secondary > Tertiary > Disabled 순으로 강조가 약해짐
  static const textPrimary = Color(0xFF444444);
  static const textSecondary = Color(0xFF3C3C3C);
  static const textTertiary = Color(0xFFA5A5A5);
  static const textDisabled = Color(0xFFF5F5F5);

  // 하단 네비게이션 바 아이콘
  static const navIconActive = Color(0xFF656565);
  static const navIconInactive = Color(0xFFB7B7B7);

  // spot_detail_screen 전용 색상
  static const textTitle = Color(0xFF060606);
  static const textLabel = Color(0xFF3C3C3C);
  static const textValue = Color(0xFF868686);
  static const textEmpty = Color(0xFFACACAC);

  static const divider = Color(0xFFE3E3E3);
  static const iconInactive = Color(0xFF7D7D7D);

  static const surfaceCircle = Color(0xFFF2F2F2);
  static const surfaceLabelColumn = Color(0xFFF7F8FA);

  static const tabInactiveBackground = Color(0xFFF0F0F0);
  static const tabBorder = Color(0xFF8F8F8F);
}
