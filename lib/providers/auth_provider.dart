import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../model/user/user.dart';
import '../services/auth/kakao_auth_service.dart';
import '../services/auth/google_auth_service.dart';
import '../services/user_service.dart';

// KakaoAuthService 인스턴스 생성
final kakaoAuthServiceProvider = Provider<KakaoAuthService>((ref) {
  return KakaoAuthService();
});

// GoogleAuthService 인스턴스 생성
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

// 로그인 상태 관리, 화면에 쓸 수 있게 연결해주는 역할
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(
    ref.read(kakaoAuthServiceProvider),
    ref.read(googleAuthServiceProvider),
  );
});

class AuthState {
  final bool isLoading; // 로그인 중인지
  final AppUser? user; // 로그인 성공한 토큰
  final String? errorMessage; // 에러 메세지
  final bool isNewUser; // 이번 로그인이 신규 가입인지

  AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.isNewUser = false,
  });

  AuthState copyWith({
    // 새로운 객체 만들어서 값 변경하기 위함
    bool? isLoading,
    AppUser? user,
    String? errorMessage,
    bool? isNewUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

// 상태 변경 로직
class AuthStateNotifier extends StateNotifier<AuthState> {
  final KakaoAuthService _kakaoAuthService;
  final GoogleAuthService _googleAuthService;

  AuthStateNotifier(this._kakaoAuthService, this._googleAuthService)
    : super(AuthState());

  // 앱 시작 시 Firebase에 남아있는 로그인 세션을 복원한다. 세션이 없거나
  // Firestore 유저 문서를 못 찾으면 게스트 상태(초기값)를 그대로 둔다 — 랜딩
  // 화면이 이 결과를 보고 로그인 화면 대신 바로 메인으로 보낼지 결정한다.
  Future<void> restoreSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final user = await UserService().getUser(firebaseUser.uid);
    if (user != null) {
      state = state.copyWith(user: user);
    }
  }

  // 카카오 로그인
  Future<void> signInWithKakao() async {
    state = state.copyWith(isLoading: true, errorMessage: null); // 1. 로딩 시작

    final result = await _kakaoAuthService.signInWithKakao(); // 2. 카카오 로그인 실행

    if (result.user != null) {
      state = state.copyWith(
        isLoading: false,
        user: result.user,
        isNewUser: result.isNewUser,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '로그인에 실패했습니다. 다시 시도해주세요.',
      );
    }
  }

  // 구글 로그인
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _googleAuthService.signInWithGoogle();

    if (result.user != null) {
      state = state.copyWith(
        isLoading: false,
        user: result.user,
        isNewUser: result.isNewUser,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '로그인에 실패했습니다. 다시 시도해주세요.',
      );
    }
  }

  // 세션에 보관된 유저 정보 갱신 (예: 접근성 프로필 저장 후)
  void setUser(AppUser user) {
    state = state.copyWith(user: user);
  }

  // 로그아웃 (provider별 분기는 여기서 처리, 화면은 결과만 소비)
  Future<bool> logout() async {
    final success = switch (state.user?.provider) {
      'kakao' => await _kakaoAuthService.logout(),
      'google' => await _googleAuthService.logout(),
      _ => false,
    };
    if (success) {
      state = AuthState();
    }
    return success;
  }

  // 회원탈퇴 (provider별 분기는 여기서 처리, 화면은 결과만 소비)
  Future<bool> deleteAccount() async {
    final success = switch (state.user?.provider) {
      'kakao' => await _kakaoAuthService.deleteAccount(),
      'google' => await _googleAuthService.deleteAccount(),
      _ => false,
    };
    if (success) {
      state = AuthState();
    }
    return success;
  }
}
