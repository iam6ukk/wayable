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

  /// 폴더 목록 실시간 구독. 정렬 기준은 사용자가 드래그로 정한 order
  /// 필드인데, order가 없는 문서를 대상으로 orderBy('order')를 걸면
  /// Firestore가 그 문서들을 아예 결과에서 빼버리므로(한 번도 순서를 안 바꾼
  /// 폴더가 통째로 사라짐), 항상 존재하는 createdAt으로 전체를 받아온 뒤
  /// order는 클라이언트에서 정렬 키로만 쓴다.
  Stream<List<BookmarkFolder>> watchFolders(String uid) {
    return _foldersRef(uid).orderBy('createdAt').snapshots().map((snapshot) {
      final folders = snapshot.docs
          .map((doc) => BookmarkFolder.fromFirestore(doc.id, doc.data()))
          .toList();
      // order가 없는(아직 순서를 안 바꾼) 폴더는 지금 이 생성순 목록에서의
      // 위치를 그대로 정렬 키로 쓴다 — List.sort는 안정 정렬을 보장하지
      // 않으므로, 매번 결정적으로 같은 순서가 나오도록 인덱스를 직접 넣는다.
      final sortKeys = <String, int>{
        for (var i = 0; i < folders.length; i++)
          folders[i].id: folders[i].order ?? i,
      };
      folders.sort((a, b) => sortKeys[a.id]!.compareTo(sortKeys[b.id]!));
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

  /// doc id는 클라이언트가 즉시 만들어내므로(서버 왕복 불필요), set()이
  /// 실제 서버 ack까지 왕복하는 걸 기다리지 않고 바로 반환한다 — 기다리면
  /// 폴더 추가 후 바텀시트가 다시 뜨는 데만 왕복 시간만큼 지연된다. 쓰기는
  /// 백그라운드로 계속 진행되고, watchFolders 구독은 로컬 캐시 갱신을 통해
  /// 서버 응답을 기다리지 않고도 거의 즉시 새 폴더를 반영한다.
  Future<BookmarkFolder> addFolder(String uid, String name) async {
    final doc = _foldersRef(uid).doc();
    doc.set({'name': name, 'createdAt': FieldValue.serverTimestamp()});
    return BookmarkFolder(id: doc.id, name: name);
  }

  Future<void> renameFolder(String uid, String folderId, String newName) {
    return _foldersRef(uid).doc(folderId).update({'name': newName});
  }

  /// 드래그로 정한 새 순서(폴더 id 순서대로)를 그대로 0..n-1 정수로 다시
  /// 매겨서 저장한다 — 기본 폴더도 포함해서 전부 다시 매기므로, 이후에는
  /// order 필드만으로 순서가 결정된다.
  Future<void> reorderFolders(String uid, List<String> orderedFolderIds) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < orderedFolderIds.length; i++) {
      batch.update(_foldersRef(uid).doc(orderedFolderIds[i]), {'order': i});
    }
    await batch.commit();
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

  /// 회원탈퇴 시 유저의 모든 북마크(폴더 + 여행지)를 지운다. 여행지 문서를
  /// 폴더 문서 삭제에 딸려가게 두지 않고 개별적으로 delete해야
  /// bookmarkCountSync의 onBookmarkSpotDeleted 트리거가 여행지별로 정상
  /// 발동해서 tourSpots.bookmarkCount도 같이 줄어든다.
  Future<void> deleteAllBookmarks(String uid) async {
    final folderDocs = await _foldersRef(uid).get();
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final folder in folderDocs.docs) {
      final spotDocs = await _spotsRef(uid, folder.id).get();
      refs.addAll(spotDocs.docs.map((doc) => doc.reference));
      refs.add(folder.reference);
    }

    // Firestore 배치는 최대 500개 쓰기까지만 허용하므로 나눠서 커밋한다.
    const chunkSize = 500;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in refs.skip(i).take(chunkSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
