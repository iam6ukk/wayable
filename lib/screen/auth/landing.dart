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

  static const _exitDuration = Duration(milliseconds: 500);
  static const _bgColor = Color(0xFFEAF4FF);
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

    // 페이드인 완료 후 화면 유지
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    _startExit();
  }

  Future<void> _startExit() async {
    setState(() => _exiting = true);
    await Future.delayed(_exitDuration);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _exitDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
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
                duration: const Duration(milliseconds: 500),
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
      duration: _exitDuration,
      curve: Curves.easeInOutCubic,
      offset: _exiting ? const Offset(0, -3.0) : Offset.zero,
      child: AnimatedOpacity(
        duration: _exitDuration,
        curve: Curves.easeOut,
        opacity: _exiting ? 0 : (visible ? 1 : 0),
        child: child,
      ),
    );
  }
}
