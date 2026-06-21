import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../model/user.dart';
import '../services/auth/kakao_auth_service.dart';

// KakaoAuthService 인스턴스 생성
final kakaoAuthServiceProvider = Provider<KakaoAuthService>((ref) {
  return KakaoAuthService();
});

// 로그인 상태 관리, 화면에 쓸 수 있게 연결해주는 역할
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(ref.read(kakaoAuthServiceProvider));
});

class AuthState {
  final bool isLoading; // 로그인 중인지
  final AppUser? user; // 로그인 성공한 토큰
  final String? errorMessage; // 에러 메세지

  AuthState({this.isLoading = false, this.user, this.errorMessage});

  AuthState copyWith({
    // 새로운 객체 만들어서 값 변경하기 위함
    bool? isLoading,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

// 상태 변경 로직
class AuthStateNotifier extends StateNotifier<AuthState> {
  final KakaoAuthService _kakaoAuthService;

  AuthStateNotifier(this._kakaoAuthService) : super(AuthState());

  Future<void> signInWithKakao() async {
    state = state.copyWith(isLoading: true, errorMessage: null); // 1. 로딩 시작

    final user = await _kakaoAuthService.signInWithKakao(); // 2. 카카오 로그인 실행

    if (user != null) {
      state = state.copyWith(isLoading: false, user: user);
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '카카오 로그인에 실패했습니다.',
      );
    }
  }

  Future<void> signOut() async {
    await _kakaoAuthService.signOut();
    state = AuthState();
  }
}
