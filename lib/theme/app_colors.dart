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
  static const bottomSheetBackground = Color(0xFFF8FCFF); // 바텀 시트 배경색
  static const barrierBackground = Color(0x33363636);

  // 텍스트 강조 단계: Primary > Secondary > Tertiary > Quaternary 순으로 강조가 약해짐
  static const textPrimary = Color(0xFF444444); // 여행지 이름, 제목
  static const textSecondary = Color(0xFF666666); // 본문, 시설정보표 왼쪽
  static const textTertiary = Color(0xFF888888); // 시설정보표 오른쪽
  static const textQuaternary = Color(0xFFA8A8A8); // 시설정보표 정보없음

  static const catchPhrase = Color(0xFF052A5F);
  static const wordmark = Color(0xFF004EBC); // 로그인 화면 Wayable 워드마크 전용
  static const slateGray = Color(0xFF697281); // 검색 아이콘, 비회원 안내 텍스트 등 중립 회색조

  // 선(스트로크)
  static const hairlineDivider = Color(0xFFE5E4E4); // 구글 로그인 버튼 테두리처럼 아주 옅은 경계선
  static const faintDivider = Color(0xFFD6D6D6); // 단순히 배경과의 적당한 구분을 원할 때
  static const boldDivider = Color(0xFF8F8F8F); // 명확히 구분할 수 있도록 하는 때

  // 아이콘: 돋보기/필터/X/정렬화살표/이미지 placeholder 등 화면 전반의 기본 아이콘 색상
  static const navIconInactive = Color(0xFFB7B7B7);

  // 하단 탭 메뉴바 아이콘 전용
  static const bottomNavActive = Color(0xFF242424); // 선택
  static const bottomNavInactive = Color(0xFFB0B2B4); // 미선택, 무장애 아이콘, 북마크 미선택

  // 무장애 프로필/필터 토글 버튼 (선택 시 흰색 = whiteBackground)
  static const toggleUnselectedBackground = Color(0xFFF5F5F5);
  static const toggleUnselected = Color(0xFF7D7D7D);

  static const surfaceCircle = Color(0xFFF2F2F2);
  static const surfaceLabelColumn = Color(0xFFF7F7F7);

  // 화면별로 흩어져 있던 로컬 색상 상수를 모아둔 것들. 여러 화면이 함께 쓰는
  // 값도 있고 한 화면 전용인 값도 있지만, 새로 만들 때 파일마다 다시
  // 선언하지 말고 여기부터 확인한다.
  static const mutedDivider = Color(0xFFE3E3E3); // 통합필터/마이페이지 구분선
  static const chipInactiveBorder = Color(0xFFC8C8C8); // 통합필터 칩 미선택 테두리
  static const searchBarBackground = Color(0x80D9D9D9); // 탐색 화면 검색창 배경
  static const inactiveSurface = Color(0xFFF2F2F2); // 탐색 화면 비활성 원형 배경
  static const emptyStateText = Color(0xFFACACAC); // 탐색 화면 빈 결과 안내 텍스트
  static const locationText = Color(0xFFBFBFBF); // 홈 화면 위치 텍스트
  static const pageBadgeBackground = Color(0xCCFFFFFF); // 홈 화면 배너 페이지 뱃지 배경
  static const pageBadgeText = Color(0xCC2D2D2D); // 홈 화면 배너 페이지 뱃지 텍스트
  static const skeletonColor = Color(0xFFEDEDED); // 홈 화면 로딩 스켈레톤
  static const cultureCardColor = Color(0xFF548389); // 홈 화면 문화 카테고리 카드
  static const restaurantCardGradient = [
    Color(0xFFE5B081),
    Color(0xFFE9C6A8),
  ]; // 홈 화면 맛집 카테고리 카드
  static const lodgingCardGradient = [
    Color(0xFFFFEADC),
    Color(0xFFFFBBA2),
  ]; // 홈 화면 숙소 카테고리 카드
  static const seasonSpring = Color(0xFF7CB342); // 홈 화면 계절 안내(임시, TO-DO)
  static const seasonSummer = Color(0xFF039BE5);
  static const seasonFall = Color(0xFFEF6C00);
  static const popupMenuBackground = Color(0xFFEEEEEE); // 점3개/정렬 팝업 메뉴 배경
  static const scrollFabBackground = Color(0xFFF0F4F8); // 상하단 이동 버튼 배경
  static const scrollFabIcon = Color(0xFF767676); // 상하단 이동 버튼 아이콘
  static const myPageCardOverlay = Color(0xB2F2F2F2); // 마이페이지 카드 반투명 배경
  static const fitLevel0Badge = Color(0xFF606060); // 적합성 lv.0
  static const fitLevel1Badge = Color(0xFFEF5350); // 적합성 lv.1
  static const fitLevel2Badge = Color(0xFFFF9800); // 적합성 lv.2
  static const fitLevel3Badge = Color(0xFF4CAF50); // 적합성 lv.3
  static const fitLevelPendingBadge = Color(0xFF9E9E9E); // 적합 레벨 배지(산정 중)
  static const faqAnswerBackground = Color(0xFFF6FCFF); // FAQ 펼친 답변 배경
}
