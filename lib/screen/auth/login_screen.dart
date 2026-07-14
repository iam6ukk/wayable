import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../screen/home_screen.dart';
import '../myPage/accessibility_screen.dart';
import '../../navigation/navigator_key.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 앱 로고 or 타이틀
              const Text(
                'WayAble',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 80),

              // 에러 메시지
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // 구글 로그인 버튼
              GestureDetector(
                onTap: authState.isLoading
                    ? null // 중복 클릭 방지
                    : () {
                        ref.read(authStateProvider.notifier).signInWithGoogle();
                      },
                child: Image.asset(
                  'assets/images/google_login_medium_wide.png',
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 12),

              // 카카오 로그인 버튼
              GestureDetector(
                onTap: authState.isLoading
                    ? null // 중복 클릭 방지
                    : () {
                        ref.read(authStateProvider.notifier).signInWithKakao();
                      },
                child: Image.asset(
                  'assets/images/kakao_login_medium_wide.png',
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 12),

              // 로딩 인디케이터
              if (authState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),

              // 비회원 버튼
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                child: const Text('비회원으로 진행하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
