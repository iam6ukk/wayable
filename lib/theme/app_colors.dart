import 'package:flutter/material.dart';

/// 앱 전역에서 재사용하는 색상 상수 모음.
class AppColors {
  AppColors._();

  // 메인 컬러
  static const primary = Color(0xFF0067FD); // 기본 버튼, 핵심 액션
  static const background = Color(0xFFE5F4FF); // 선택 배경,안내 영역
  static const accent = Color(0xFFFFCD21); // 추천, 저장, 강조 정보

  // 배경
  static const whiteBackground = Colors.white;
  static const blackBackground = Colors.black;
  static const bottomSheetBackground = Color(0xFFF8FCFF); // 바텀 시트 배경색
  static const barrierBackground = Color(0x33363636);

  // 텍스트 강조 단계: Primary > Secondary > Tertiary > Quaternary 순으로 강조가 약해짐
  static const textPrimary = Color(0xFF444444);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF888888);
  static const textQuaternary = Color(0xFFABABAB);

  static const textByBlackBackground = Color(0xFFCCCCCC);
  static const catchPhrase = Color(0xFF052A5F);

  // 선
  static const faintDivider = Color(0xFFD6D6D6);
  static const boldDivider = Color(0xFF8F8F8F);

  // 하단 네비게이션 바 아이콘
  static const navIconActive = Color(0xFF656565);
  static const navIconInactive = Color(0xFFB7B7B7);

  // spot_detail_screen 전용 색상
  // static const textTitle = Color(0xFF060606);
  // static const textLabel = Color(0xFF3C3C3C);
  // static const textValue = Color(0xFF868686);
  // static const textEmpty = Color(0xFFACACAC);

  // static const divider = Color(0xFFE3E3E3);
  // static const iconInactive = Color(0xFF7D7D7D);

  // static const surfaceCircle = Color(0xFFF2F2F2);
  static const surfaceLabelColumn = Color(0xFFF7F8FA);

  // static const tabInactiveBackground = Color(0xFFF0F0F0);
  // static const tabBorder = Color(0xFF8F8F8F);
}
