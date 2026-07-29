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
    : super(BookmarkState(folders: const [], spotsByFolderId: const {})) {
    final uid = _uid;
    if (uid != null) _start(uid);
  }

  final String? _uid;
  final _service = BookmarkService();
  StreamSubscription<List<BookmarkFolder>>? _foldersSub;
  final Map<String, StreamSubscription<List<TourSpot>>> _spotsSubs = {};

  Future<void> _start(String uid) async {
    await _service.ensureDefaultFolder(uid);
    _foldersSub = _service.watchFolders(uid).listen((folders) {
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

  Future<void> deleteFolder(BookmarkFolder folder) {
    return _service.deleteFolder(_requireUid(), folder.id);
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
