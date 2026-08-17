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

  // 회원탈퇴 시 users/{uid} 문서 삭제
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      AppLogger.info('[UserService] 유저 문서 삭제 완료');
    } catch (e) {
      AppLogger.error('[UserService] 유저 문서 삭제 실패', error: e);
      rethrow;
    }
  }
}
