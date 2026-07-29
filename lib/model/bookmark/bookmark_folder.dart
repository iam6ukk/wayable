/// 저장목록 폴더. users/{uid}/bookmarks/{folderId} 문서와 대응한다.
/// 'default' id는 모든 유저에게 고정으로 존재하는 기본 폴더를 가리킨다.
class BookmarkFolder {
  BookmarkFolder({required this.id, required this.name});

  final String id;
  String name;

  factory BookmarkFolder.fromFirestore(String id, Map<String, dynamic> data) {
    return BookmarkFolder(id: id, name: (data['name'] as String?) ?? '');
  }
}
