import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wayable/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../navigation/main_shell.dart';
import '../myPage/accessibility_screen.dart';
import '../../navigation/navigator_key.dart';
import '../../widgets/app_dialog.dart';
import 'login_loading_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _wordmarkVisible = false;
  bool _buttonsVisible = false;

  @override
  void initState() {
    super.initState();
    _startEntrance();
  }

  Future<void> _startEntrance() async {
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() => _wordmarkVisible = true);

    // 워드마크 페이드인이 끝난 뒤 로그인/비회원 버튼 페이드인
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _buttonsVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // 로그인 성공 시 다음 화면으로 이동
    // 신규 유저는 접근성 프로필 설정 화면을 거쳐 홈으로, 기존 유저는 바로 홈으로 이동한다.
    ref.listen(authStateProvider, (previous, next) {
      if (next.user != null && previous?.user == null) {
        // 로그인 성공: 로딩 화면 + 로그인 화면을 걷어내고 다음 화면으로 교체
        if (next.isNewUser) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => AccessibilityScreen(
                onComplete: () {
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
              ),
            ),
            (route) => false,
          );
        } else {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        }
      } else if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        // 로그인 실패: 떠 있던 로딩 화면을 닫고 에러 다이얼로그 표시
        if (navigatorKey.currentState?.canPop() ?? false) {
          navigatorKey.currentState?.pop();
        }
        showInfoDialog(context, title: '로그인에 실패했습니다.', content: '다시 시도해 주세요.');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // Stack + Positioned 구조 (overflow 에러가 발생하지 않는 원래 안정적인 구조로 복귀)
      body: Stack(
        children: [
          // 상단: 로고 + Wayable 워드마크 (갤럭시 표준 360x800 Figma 프레임 기준)
          Positioned(
            top: 217.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/wayable.png',
                      width: 106.w,
                      height: 108.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _wordmarkVisible ? 1 : 0,
                    child: Text(
                      'Wayable',
                      style: TextStyle(
                        fontFamily: 'CalSans',
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.wordmark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단: 로그인 버튼 + 비회원 텍스트
          Positioned(
            top: 500.h,
            left: 31.w,
            right: 31.w,
            child: IgnorePointer(
              ignoring: !_buttonsVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _buttonsVisible ? 1 : 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 카카오 로그인 버튼
                    GestureDetector(
                      onTap: authState.isLoading
                          ? null
                          : () async {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (_, _, _) =>
                                      const LoginLoadingScreen(),
                                ),
                              );
                              await ref
                                  .read(authStateProvider.notifier)
                                  .signInWithKakao();
                            },
                      child: Container(
                        width: double.infinity,
                        height: 44.9.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDDC3F),
                          borderRadius: BorderRadius.all(
                            Radius.circular(5.5.r),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 3.w,
                              child: Image.asset(
                                'assets/images/kakao.png',
                                width: 41.r,
                                height: 41.r,
                              ),
                            ),
                            Text(
                              '카카오 로그인',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 구글 로그인 버튼
                    GestureDetector(
                      onTap: authState.isLoading
                          ? null
                          : () async {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (_, _, _) =>
                                      const LoginLoadingScreen(),
                                ),
                              );
                              await ref
                                  .read(authStateProvider.notifier)
                                  .signInWithGoogle();
                            },
                      child: Container(
                        margin: EdgeInsets.only(top: 15.h),
                        width: double.infinity,
                        height: 44.9.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          border: Border.all(
                            color: AppColors.hairlineDivider,
                            width: 0.2,
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(6.4.r),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 6.5.w,
                              child: Image.asset(
                                'assets/images/google.png',
                                width: 29.3.r,
                                height: 29.3.r,
                              ),
                            ),
                            Text(
                              'Google 계정으로 로그인',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 25.h),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainShell()),
                        );
                      },
                      style: TextButton.styleFrom(
                        overlayColor: Colors.transparent,
                      ),
                      child: Text(
                        '비회원으로 진행하기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.slateGray,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.slateGray.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
