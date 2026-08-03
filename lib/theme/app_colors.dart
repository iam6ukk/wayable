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
  static const textPrimary = Color(0xFF444444); // 여행지 이름, 제목
  static const textSecondary = Color(0xFF666666); // 본문, 시설정보표 왼쪽
  static const textTertiary = Color(0xFF888888); // 시설정보표 오른쪽
  static const textQuaternary = Color(0xFFA8A8A8); // 시설정보표 정보없음
  static const facilityLabelText = Color(0xFF3C3C3C); // 시설정보표/편의정보 라벨 텍스트

  static const textByBlackBackground = Color(0xFFCCCCCC); // 검정 배경에서 흰색 대신
  static const catchPhrase = Color(0xFF052A5F);
  static const wordmark = Color(0xFF004EBC); // 로그인 화면 Wayable 워드마크 전용
  static const slateGray = Color(0xFF697281); // 검색 아이콘, 비회원 안내 텍스트 등 중립 회색조

  // 선(스트로크)
  static const hairlineDivider = Color(0xFFE5E4E4); // 구글 로그인 버튼 테두리처럼 아주 옅은 경계선
  static const faintDivider = Color(0xFFD6D6D6); // 단순히 배경과의 적당한 구분을 원할 때
  static const boldDivider = Color(0xFF8F8F8F); // 명확히 구분할 수 있도록 하는 때

  // 무장애 레벨링
  static const accessibilityLevel1 = Color(0xFFEF5350); // 적합성 Lv.1
  static const accessibilityLevel2 = Color(0xFFFF9800); // 적합성 Lv.2
  static const accessibilityLevel3 = Color(0xFF4CAF50); // 적합성 Lv.3
  static const accessibilityLevelPending = Color(0xFF9E9E9E); // 레벨 산정중

  // 아이콘: 돋보기/필터/X/정렬화살표/이미지 placeholder 등 화면 전반의 기본 아이콘 색상
  static const navIconActive = Color(0xFF656565);
  static const navIconInactive = Color(0xFFB7B7B7);

  // 하단 탭 메뉴바 아이콘 전용
  static const bottomNavActive = Color(0xFF242424); // 선택
  static const bottomNavInactive = Color(0xFFB0B2B4); // 미선택, 무장애 아이콘, 북마크 미선택

  // 무장애 프로필/필터 토글 버튼 (선택 시 흰색 = whiteBackground)
  static const toggleUnselected = Color(0xFF7D7D7D);

  // static const surfaceCircle = Color(0xFFF2F2F2);
  static const surfaceLabelColumn = Color(0xFFF7F7F7);
}
