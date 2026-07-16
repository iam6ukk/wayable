import 'package:flutter/material.dart';
import 'package:wayable/screen/auth/login_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _titleVisible = false;
  bool _subtitleVisible = false;
  bool _logoVisible = false;
  bool _exiting = false; // true가 되면 대제목/소제목이 위로 사라짐

  static const _bgColor = Color(0xFFE8F4FF);
  static const _titleColor = Color(0xFF052A5F);

  @override
  void initState() {
    super.initState();
    _startEntrance();
  }

  Future<void> _startEntrance() async {
    // 대제목 → 소제목 → 로고 순으로 살짝 시차를 두고 페이드인
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _titleVisible = true);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _subtitleVisible = true);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _logoVisible = true);

    // 페이드인 완료 후 화면 유지 (전체 노출 약 2.5~2.7초 지점에서 전환 시작)
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    _startExit();
  }

  Future<void> _startExit() async {
    setState(() => _exiting = true); // 대제목/소제목 슬라이드업 + 페이드아웃
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 배경은 즉시 전환, 로고 이동은 Hero가 자동으로 애니메이션 처리
          return child;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildExitingText(
                visible: _titleVisible,
                child: const Text(
                  '가고 싶은 곳, 갈 수 있는 길',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 27,
                    color: _titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildExitingText(
                visible: _subtitleVisible,
                child: const Text(
                  '장벽 없이 나답게 떠나는 여행',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                    color: _titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _logoVisible ? 1 : 0,
                child: Hero(
                  tag: 'app_logo',
                  child: Image.asset('assets/images/wayable.png', width: 150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 대제목/소제목 공통: 진입 시 페이드인, exiting=true가 되면 위로 슬라이드하며 페이드아웃
  Widget _buildExitingText({required bool visible, required Widget child}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      offset: _exiting ? const Offset(0, -0.4) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _exiting ? 0 : (visible ? 1 : 0),
        child: child,
      ),
    );
  }
}
