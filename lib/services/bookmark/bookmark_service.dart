import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/bookmark/bookmark_folder.dart';
import '../../model/tour/tour_spot.dart';

/// users/{uid}/bookmarks/{folderId}(/spots/{spotId}) 를 다루는 서비스.
/// firestore.rules의 북마크 규칙과 그대로 대응한다.
class BookmarkService {
  final _users = FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> _foldersRef(String uid) =>
      _users.doc(uid).collection('bookmarks');

  CollectionReference<Map<String, dynamic>> _spotsRef(
    String uid,
    String folderId,
  ) => _foldersRef(uid).doc(folderId).collection('spots');

  /// 폴더 목록 실시간 구독. 'default'(기본 폴더)는 생성 순서와 무관하게 항상
  /// 맨 앞에 오도록 클라이언트에서 재배치한다.
  Stream<List<BookmarkFolder>> watchFolders(String uid) {
    return _foldersRef(uid).orderBy('createdAt').snapshots().map((snapshot) {
      final folders = snapshot.docs
          .map((doc) => BookmarkFolder.fromFirestore(doc.id, doc.data()))
          .toList();
      final defaultIndex = folders.indexWhere((f) => f.id == 'default');
      if (defaultIndex > 0) {
        folders.insert(0, folders.removeAt(defaultIndex));
      }
      return folders;
    });
  }

  /// 폴더 하나에 저장된 여행지 실시간 구독.
  Stream<List<TourSpot>> watchSpots(String uid, String folderId) {
    return _spotsRef(uid, folderId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TourSpot.fromBookmarkDoc(doc.data()))
              .toList(),
        );
  }

  /// 계정 생성 이후 언제든 호출해도 안전한 멱등 처리 — 기본 폴더 문서가 없을
  /// 때만 만든다. 회원가입 직후는 물론, 그 이전에 만들어진 계정이 나중에
  /// 이 화면에 처음 들어올 때도 스스로 채워지도록 앱 시작 경로에서 호출한다.
  Future<void> ensureDefaultFolder(String uid) async {
    final ref = _foldersRef(uid).doc('default');
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set({'name': '기본 폴더', 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<BookmarkFolder> addFolder(String uid, String name) async {
    final doc = _foldersRef(uid).doc();
    await doc.set({'name': name, 'createdAt': FieldValue.serverTimestamp()});
    return BookmarkFolder(id: doc.id, name: name);
  }

  Future<void> renameFolder(String uid, String folderId, String newName) {
    return _foldersRef(uid).doc(folderId).update({'name': newName});
  }

  /// Firestore는 상위 문서를 지워도 서브컬렉션이 같이 지워지지 않으므로,
  /// 폴더 안 여행지 문서를 먼저 다 지우고 나서 폴더 문서를 지운다.
  Future<void> deleteFolder(String uid, String folderId) async {
    final spotDocs = await _spotsRef(uid, folderId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in spotDocs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_foldersRef(uid).doc(folderId));
    await batch.commit();
  }

  /// 문서 id를 spot의 contentId로 고정해서, 같은 여행지를 같은 폴더에 다시
  /// 저장해도 중복 없이 덮어써지게 한다.
  Future<void> saveSpotToFolder(String uid, String folderId, TourSpot spot) {
    return _spotsRef(uid, folderId).doc(spot.contentId).set({
      ...spot.toBookmarkDoc(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsaveSpot(String uid, String folderId, String contentId) {
    return _spotsRef(uid, folderId).doc(contentId).delete();
  }
}
