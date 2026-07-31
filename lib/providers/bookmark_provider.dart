import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../model/bookmark/bookmark_folder.dart';
import '../model/tour/tour_spot.dart';
import '../services/bookmark/bookmark_service.dart';
import 'auth_provider.dart';

/// 저장목록(북마크) 상태. Firestore(users/{uid}/bookmarks/...)를 실시간
/// 구독해서 반영한다 — 저장목록 화면, 폴더 편집 화면, 여행지 상세화면의 저장
/// 바텀시트가 전부 이 provider 하나를 공유해서 어느 화면에서 바꾸든 서로
/// 바로 반영되고, 다른 기기에서 바꾼 내용도 실시간으로 들어온다.
///
/// 로그인한 유저(uid)가 바뀌면(로그아웃/다른 계정 로그인) Riverpod가 이
/// provider를 자동으로 새로 만들어서 이전 구독을 정리하고 새 uid로 다시
/// 구독한다 — 계정을 바꿔도 이전 계정의 북마크가 남아있지 않다.
final bookmarkProvider = StateNotifierProvider<BookmarkNotifier, BookmarkState>(
  (ref) {
    final uid = ref.watch(authStateProvider.select((state) => state.user?.uid));
    return BookmarkNotifier(uid);
  },
);

class BookmarkState {
  BookmarkState({
    required this.folders,
    required this.spotsByFolderId,
    this.loadedFolderIds = const {},
  });

  final List<BookmarkFolder> folders;
  final Map<String, List<TourSpot>> spotsByFolderId;

  /// 이 폴더의 여행지 목록을 Firestore에서 최소 한 번은 받아왔는지. 이제 막
  /// 구독을 시작해서 아직 첫 스냅샷이 안 온 폴더와, 실제로 저장된 게 하나도
  /// 없는 폴더를 구분하는 데 쓰인다([_FolderSpotList]가 로딩 중인지 "저장된
  /// 여행지가 없어요"를 보여줄지 판단하는 기준).
  final Set<String> loadedFolderIds;

  List<TourSpot> spotsIn(String folderId) =>
      spotsByFolderId[folderId] ?? const [];

  bool isSaved(String contentId) => spotsByFolderId.values.any(
    (spots) => spots.any((spot) => spot.contentId == contentId),
  );

  /// 이 여행지가 저장된 폴더의 id. 여러 폴더에 저장돼 있을 수는 없다는
  /// 전제(폴더당 저장이 아니라 여행지당 폴더 하나) 하에 첫 번째로 찾은
  /// 폴더를 반환한다.
  String? folderIdContaining(String contentId) {
    for (final entry in spotsByFolderId.entries) {
      if (entry.value.any((spot) => spot.contentId == contentId)) {
        return entry.key;
      }
    }
    return null;
  }

  BookmarkState copyWith({
    List<BookmarkFolder>? folders,
    Map<String, List<TourSpot>>? spotsByFolderId,
    Set<String>? loadedFolderIds,
  }) {
    return BookmarkState(
      folders: folders ?? this.folders,
      spotsByFolderId: spotsByFolderId ?? this.spotsByFolderId,
      loadedFolderIds: loadedFolderIds ?? this.loadedFolderIds,
    );
  }
}

class BookmarkNotifier extends StateNotifier<BookmarkState> {
  BookmarkNotifier(this._uid)
    : super(
        BookmarkState(
          // Firestore 왕복이 끝나기 전에도 저장목록 화면이 탭 구조를 바로
          // 그릴 수 있도록 '기본 폴더'를 낙관적으로 미리 채워둔다. 기본
          // 폴더는 모든 유저에게 항상 존재하는 게 보장되므로 이 자리표시자가
          // 틀릴 일은 없고, 실제 폴더 목록이 도착하면 그 값으로 바로
          // 교체된다.
          folders: _uid == null
              ? const []
              : [BookmarkFolder(id: 'default', name: '기본 폴더')],
          spotsByFolderId: const {},
        ),
      ) {
    final uid = _uid;
    if (uid != null) _start(uid);
  }

  final String? _uid;
  final _service = BookmarkService();
  StreamSubscription<List<BookmarkFolder>>? _foldersSub;
  final Map<String, StreamSubscription<List<TourSpot>>> _spotsSubs = {};

  void _start(String uid) {
    // ensureDefaultFolder(존재 확인 후 없으면 생성) 왕복을 다 기다린 다음에야
    // watchFolders 구독을 시작하면, 화면이 뜨는 데만 순차적으로 왕복 두 번이
    // 필요해진다. 두 요청을 동시에 시작해서 하나로 줄인다 — 기본 폴더
    // 생성이 아직 서버에 반영되기 전에 컬렉션이 비어 있는 스냅샷이 먼저
    // 도착할 수 있는데, 그 빈 상태로 위 낙관적 기본 폴더 탭을 지워버리면
    // 탭이 잠깐 사라졌다 다시 생기는 것처럼 보이므로 무시한다.
    unawaited(_service.ensureDefaultFolder(uid));
    _foldersSub = _service.watchFolders(uid).listen((folders) {
      if (folders.isEmpty && state.folders.isNotEmpty) return;
      state = state.copyWith(folders: folders);
      _syncSpotSubscriptions(uid, folders);
    });
  }

  /// 폴더 목록이 바뀔 때마다(추가/삭제) 폴더별 여행지 구독도 맞춰 늘리고
  /// 줄인다 — 새로 생긴 폴더는 구독을 시작하고, 없어진 폴더는 구독을
  /// 끊는다.
  void _syncSpotSubscriptions(String uid, List<BookmarkFolder> folders) {
    final currentIds = folders.map((f) => f.id).toSet();

    final removedIds = _spotsSubs.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    if (removedIds.isNotEmpty) {
      final spotsByFolderId = {...state.spotsByFolderId};
      final loadedFolderIds = {...state.loadedFolderIds};
      for (final id in removedIds) {
        _spotsSubs.remove(id)?.cancel();
        spotsByFolderId.remove(id);
        loadedFolderIds.remove(id);
      }
      state = state.copyWith(
        spotsByFolderId: spotsByFolderId,
        loadedFolderIds: loadedFolderIds,
      );
    }

    for (final folder in folders) {
      if (_spotsSubs.containsKey(folder.id)) continue;
      _spotsSubs[folder.id] = _service.watchSpots(uid, folder.id).listen((
        spots,
      ) {
        final spotsByFolderId = {...state.spotsByFolderId};
        spotsByFolderId[folder.id] = spots;
        state = state.copyWith(
          spotsByFolderId: spotsByFolderId,
          loadedFolderIds: {...state.loadedFolderIds, folder.id},
        );
      });
    }
  }

  @override
  void dispose() {
    _foldersSub?.cancel();
    for (final sub in _spotsSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인하지 않은 상태에서는 저장목록을 사용할 수 없습니다.');
    }
    return uid;
  }

  Future<BookmarkFolder> addFolder(String name) {
    return _service.addFolder(_requireUid(), name);
  }

  Future<void> renameFolder(BookmarkFolder folder, String newName) {
    return _service.renameFolder(_requireUid(), folder.id, newName);
  }

  /// 삭제 확인 다이얼로그에서 확인을 누른 즉시 화면에서 지워져야 자연스러운데,
  /// 실제 삭제는 하위 spots 문서를 먼저 조회한 뒤 배치 삭제하는 왕복이 있어
  /// 그 응답을 기다리면 잠깐 화면에 그대로 남아 있는 것처럼 보인다. 그래서
  /// Firestore 작업을 기다리지 않고 로컬 상태부터 먼저 지운다.
  Future<void> deleteFolder(BookmarkFolder folder) async {
    final uid = _requireUid();
    final folders = state.folders.where((f) => f.id != folder.id).toList();
    final spotsByFolderId = {...state.spotsByFolderId}..remove(folder.id);
    final loadedFolderIds = {...state.loadedFolderIds}..remove(folder.id);
    state = state.copyWith(
      folders: folders,
      spotsByFolderId: spotsByFolderId,
      loadedFolderIds: loadedFolderIds,
    );
    _spotsSubs.remove(folder.id)?.cancel();

    await _service.deleteFolder(uid, folder.id);
  }

  /// 드래그로 정한 새 순서를 바로 화면에 반영하고, 실제 저장(Firestore 배치
  /// 업데이트)은 백그라운드로 진행한다 — 손을 뗀 순간 그 위치에 고정되어야
  /// 자연스럽다.
  Future<void> reorderFolders(List<BookmarkFolder> newOrder) async {
    state = state.copyWith(folders: newOrder);
    await _service.reorderFolders(
      _requireUid(),
      newOrder.map((f) => f.id).toList(),
    );
  }

  /// 같은 여행지를 다른 폴더로 옮겨 저장하는 경우까지 포함해, 먼저 기존
  /// 저장 위치에서 지운 뒤 선택한 폴더에 새로 저장한다.
  Future<void> saveSpotToFolder(String folderId, TourSpot spot) async {
    final uid = _requireUid();
    final previousFolderId = state.folderIdContaining(spot.contentId);
    if (previousFolderId != null && previousFolderId != folderId) {
      await _service.unsaveSpot(uid, previousFolderId, spot.contentId);
    }
    await _service.saveSpotToFolder(uid, folderId, spot);
  }

  /// 북마크 해제. 어느 폴더에 저장돼 있든 찾아서 지운다.
  Future<void> unsaveSpot(String contentId) async {
    final uid = _requireUid();
    final folderId = state.folderIdContaining(contentId);
    if (folderId == null) return;
    await _service.unsaveSpot(uid, folderId, contentId);
  }
}
