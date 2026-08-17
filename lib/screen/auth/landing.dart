import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wayable/navigation/main_shell.dart';
import 'package:wayable/providers/auth_provider.dart';
import 'package:wayable/screen/auth/login_screen.dart';
import 'package:wayable/theme/app_colors.dart';

// Hero flight(위치/크기 보간)에 easeInOutCubic 커브를 적용해 축소 움직임을 매끄럽게 만듦
class _EasedRectTween extends Tween<Rect?> {
  _EasedRectTween({required Rect? begin, required Rect? end})
    : super(begin: begin, end: end);

  @override
  Rect? lerp(double t) {
    return Rect.lerp(begin, end, Curves.easeInOutCubic.transform(t));
  }
}

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  bool _logoVisible = false;
  bool _titleVisible = false;
  bool _subtitleVisible = false;
  bool _exiting = false; // true가 되면 캐치프레이즈가 제자리에서 페이드아웃

  // 전환 애니메이션 지속시간 (아래 _startExit의 대기시간과 반드시 일치시킬 것)
  static const _exitDuration = Duration(milliseconds: 550);

  // 스플래시 애니메이션과 동시에 시작해서, 화면 전환 시점엔 이미 끝나 있게 한다
  // (겹치지 않으면 로그인 화면이 잠깐 보였다가 메인으로 바뀌는 깜빡임이 생김).
  late final Future<void> _restoreSessionFuture;

  @override
  void initState() {
    super.initState();
    _restoreSessionFuture = ref.read(authStateProvider.notifier).restoreSession();
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
    // 세션 복원이 애니메이션보다 오래 걸리는 드문 경우에도, 로그인 화면이
    // 잠깐 보였다가 메인으로 바뀌는 깜빡임 없이 결과가 확정된 뒤에만 넘어간다.
    await Future.wait([Future.delayed(_exitDuration), _restoreSessionFuture]);
    if (!mounted) return;

    final isLoggedIn = ref.read(authStateProvider).user != null;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _exitDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            isLoggedIn ? const MainShell() : const LoginScreen(),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 로고 - 상단 배치, 갤럭시 표준(360x800) Figma 프레임 기준 123x125
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _logoVisible ? 1 : 0,
                child: Hero(
                  tag: 'app_logo',
                  createRectTween: (begin, end) =>
                      _EasedRectTween(begin: begin, end: end),
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/images/common/wayable.png',
                      width: 123.w,
                      height: 125.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 42.h),

              // 대제목 - exit 시 슬라이드 없이 제자리에서 페이드아웃만
              _buildFadeText(
                visible: _titleVisible,
                child: Text(
                  '가고 싶은 곳, 갈 수 있는 길',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 24.sp,
                    color: AppColors.catchPhrase,
                  ),
                ),
              ),
              SizedBox(height: 7.h),

              // 소제목 - 마찬가지로 제자리에서 페이드아웃만
              _buildFadeText(
                visible: _subtitleVisible,
                child: Text(
                  '장벽 없이 나답게 떠나는 여행',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
                    fontSize: 18.sp,
                    color: AppColors.catchPhrase,
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
