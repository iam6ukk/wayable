import 'package:wayable/model/user/user.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  // users/{uid} 문서 있는지 확인
  Future<bool> userExists(String uid) async {
    try {
      final userInfo = await _db.collection('users').doc(uid).get();
      AppLogger.debug('[UserService] userExists 결과: ${userInfo.exists}');
      return userInfo.exists;
    } catch (e) {
      AppLogger.error('[UserService] 유저 정보 확인 실패', error: e);
      return false;
    }
  }

  // 신규 유저 Firestore에 저장
  Future<void> createUser(AppUser user) async {
    try {
      AppLogger.debug('[UserService] Firestore 저장 시도 중...');
      await _db.collection('users').doc(user.uid).set(user.toFirestore());
      AppLogger.info('[UserService] 신규 유저 저장 완료');
    } catch (e) {
      AppLogger.error('[UserService] 유저 저장 실패', error: e);
      rethrow;
    }
  }

  // 기존 유저 정보 일부 업데이트 (접근성 프로필 등)
  Future<void> updateUser(AppUser user) async {
    try {
      AppLogger.debug('[UserService] Firestore 업데이트 시도 중...');
      final data = user.toFirestore();
      // SetOptions.merge(true)는 accessibilityFieldsByProfile 같은 중첩 맵을
      // 키 단위로 병합해버려서, 이번에 뺀 대분류의 예전 키가 안 지워지고
      // 계속 남는 문제가 있었다. mergeFields로 최상위 필드 경로를 명시하면
      // 그 필드는 통째로 덮어써져서, 상세히 안 건드린 다른 필드는 유지하면서
      // accessibilityFieldsByProfile은 이번 값으로 완전히 교체된다.
      await _db
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(mergeFields: data.keys.toList()));
      AppLogger.info('[UserService] 유저 정보 업데이트 완료');
    } catch (e) {
      AppLogger.error('[UserService] 유저 정보 업데이트 실패', error: e);
      rethrow;
    }
  }

  // 기존 유저 Firestore에서 조회
  Future<AppUser?> getUser(String uid) async {
    try {
      final userInfo = await _db.collection('users').doc(uid).get();
      if (!userInfo.exists) return null;
      return AppUser.fromFirestore(userInfo);
    } catch (e) {
      AppLogger.error('[UserService] 유저 조회 실패', error: e);
      return null;
    }
  }
}
