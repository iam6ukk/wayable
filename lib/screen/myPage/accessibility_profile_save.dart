import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../utils/app_logger.dart';

/// 접근성 프로필 마법사 각 단계에서 공통으로 쓰는 부분 저장 로직.
/// 건너뛰기 시 "그 시점까지 입력한 내용은 저장하고 나가기"에, 그리고 4단계의
/// 실제 "저장하기" 버튼에도 함께 쓴다 — 인자로 넘기지 않은 필드는
/// AppUser.copyWith 규칙에 따라 기존 저장값을 그대로 유지한다(예: 2단계에서
/// 건너뛰면 지역 필드는 손대지 않는다).
///
/// 로그인 정보가 없거나(비정상 경로) Firestore 업데이트가 실패하면 false를
/// 반환한다 — 실패를 사용자에게 보여줄지(저장하기) 조용히 넘어갈지(건너뛰기)는
/// 호출부가 결정한다.
Future<bool> saveAccessibilityProfile(
  WidgetRef ref, {
  Map<String, List<String>>? accessibilityFieldsByProfile,
  String? interestSidoCode,
  List<String>? interestSigunguCodes,
}) async {
  final currentUser = ref.read(authStateProvider).user;
  if (currentUser == null) return false;

  final updatedUser = currentUser.copyWith(
    accessibilityFieldsByProfile: accessibilityFieldsByProfile,
    interestSidoCode: interestSidoCode,
    interestSigunguCodes: interestSigunguCodes,
  );

  try {
    await UserService().updateUser(updatedUser);
    ref.read(authStateProvider.notifier).setUser(updatedUser);
    return true;
  } catch (e) {
    AppLogger.error('[AccessibilityProfileSave] 저장 실패', error: e);
    return false;
  }
}
