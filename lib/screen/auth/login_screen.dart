import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // 로그인 성공 시 다음 화면으로 이동 (예시: 홈 화면)
    ref.listen(authStateProvider, (previous, next) {
      if (next.user != null) {
        // TODO: 홈 화면으로 이동
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
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
            ],
          ),
        ),
      ),
    );
  }
}
