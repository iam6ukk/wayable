import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wayable/screen/auth/login_screen.dart';

// Hero flight(위치/크기 보간)에 easeInOutCubic 커브를 적용해 축소 움직임을 매끄럽게 만듦
class _EasedRectTween extends Tween<Rect?> {
  _EasedRectTween({required Rect? begin, required Rect? end})
    : super(begin: begin, end: end);

  @override
  Rect? lerp(double t) {
    return Rect.lerp(begin, end, Curves.easeInOutCubic.transform(t));
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _logoVisible = false;
  bool _titleVisible = false;
  bool _subtitleVisible = false;
  bool _exiting = false; // true가 되면 캐치프레이즈가 제자리에서 페이드아웃

  // 전환 애니메이션 지속시간 (아래 _startExit의 대기시간과 반드시 일치시킬 것)
  static const _exitDuration = Duration(milliseconds: 550);
  static const _bgColor = Color(0xFFEAF4FF);
  static const _titleColor = Color(0xFF052A5F);

  @override
  void initState() {
    super.initState();
    _startEntrance();
  }

  Future<void> _startEntrance() async {
    // 로고 → 대제목 → 소제목 순으로 살짝 시차를 두고 페이드인
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _logoVisible = true);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _titleVisible = true);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _subtitleVisible = true);

    // 페이드인 완료 후 화면 유지
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    _startExit();
  }

  Future<void> _startExit() async {
    // 캐치프레이즈(대제목/소제목)만 제자리에서 페이드아웃 시작
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
              // 로고 - 상단 배치, 140x140
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _logoVisible ? 1 : 0,
                child: Hero(
                  tag: 'app_logo',
                  createRectTween: (begin, end) =>
                      _EasedRectTween(begin: begin, end: end),
                  child: Image.asset(
                    'assets/images/wayable.png',
                    width: 140.r,
                    height: 140.r,
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // 대제목 - exit 시 슬라이드 없이 제자리에서 페이드아웃만
              _buildFadeText(
                visible: _titleVisible,
                child: Text(
                  '가고 싶은 곳, 갈 수 있는 길',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 27.sp,
                    color: _titleColor,
                  ),
                ),
              ),
              SizedBox(height: 6.h),

              // 소제목 - 마찬가지로 제자리에서 페이드아웃만
              _buildFadeText(
                visible: _subtitleVisible,
                child: Text(
                  '장벽 없이 나답게 떠나는 여행',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
                    fontSize: 20.sp,
                    color: _titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 캐치프레이즈 공통: 진입 시 페이드인, exiting=true가 되면 위치 변화 없이 페이드아웃만
  Widget _buildFadeText({required bool visible, required Widget child}) {
    return AnimatedOpacity(
      duration: _exitDuration,
      curve: Curves.easeOut,
      opacity: _exiting ? 0 : (visible ? 1 : 0),
      child: child,
    );
  }
}
