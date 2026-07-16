import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../screen/home_screen.dart';
import '../myPage/accessibility_screen.dart';
import '../../navigation/navigator_key.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _wordmarkVisible = false;
  bool _buttonsVisible = false;

  // 랜딩페이지와 동일한 배경색 (전환이 끊기지 않고 이어지도록)
  static const _bgColor = Color(0xFFE8F4FF);

  @override
  void initState() {
    super.initState();
    _startEntrance();
  }

  Future<void> _startEntrance() async {
    // 랜딩페이지의 Hero 전환(500ms)이 끝난 직후 워드마크 페이드인 시작
    await Future.delayed(const Duration(milliseconds: 500));
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
        if (next.isNewUser) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AccessibilityScreen(
                onComplete: () {
                  // LoginScreen은 이미 pushReplacement로 트리에서 빠졌으므로
                  // 여기서 캡처한 context 대신 전역 navigatorKey로 이동해야 한다.
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 상단: 로고 + Wayable 워드마크 (화면 최상단에서 197px)
          Positioned(
            top: 197,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset('assets/images/wayable.png', width: 150),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _wordmarkVisible ? 1 : 0,
                    child: const Text(
                      'Wayable',
                      style: TextStyle(
                        fontFamily: 'CalSans',
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004EBC),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단: 로그인 버튼 + 비회원 텍스트
          Positioned(
            bottom: 114,
            left: 34,
            right: 34,
            child: IgnorePointer(
              ignoring: !_buttonsVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _buttonsVisible ? 1 : 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 에러 메시지
                    if (authState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    // 카카오 로그인 버튼
                    GestureDetector(
                      onTap: authState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(authStateProvider.notifier)
                                  .signInWithGoogle();
                            },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDDC3F),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '카카오 로그인',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    // 구글 로그인 버튼
                    GestureDetector(
                      onTap: authState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(authStateProvider.notifier)
                                  .signInWithGoogle();
                            },
                      child: Container(
                        margin: const EdgeInsets.only(top: 18),
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          border: Border.all(
                            color: const Color(0xFF747775),
                            width: 0.2,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Google 계정으로 로그인',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    if (authState.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(),
                      ),

                    const SizedBox(height: 20),

                    // 비회원 버튼 (하단에서 114px 지점)
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      },
                      child: Text(
                        '비회원으로 진행하기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF697281),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(
                            0xFF697281,
                          ).withValues(alpha: 0.3),
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
