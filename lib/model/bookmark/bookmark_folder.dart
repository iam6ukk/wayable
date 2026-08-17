import 'package:cloud_firestore/cloud_firestore.dart';

/// 저장목록 폴더. users/{uid}/bookmarks/{folderId} 문서와 대응한다.
/// 'default' id는 모든 유저에게 고정으로 존재하는 기본 폴더를 가리킨다.
class BookmarkFolder {
  BookmarkFolder({
    required this.id,
    required this.name,
    this.order,
    this.createdAt,
  });

  final String id;
  String name;

  /// 사용자가 드래그로 정한 표시 순서. 아직 한 번도 순서를 바꾼 적 없는
  /// 폴더는 이 값이 없고(null), 그 경우 생성순(=Firestore 조회 순서)을
  /// 그대로 쓴다.
  final int? order;

  /// 폴더 편집 화면의 정렬(최신순/오래된순) 기준. 낙관적으로 미리 채워둔
  /// 자리표시자 폴더에는 아직 값이 없을 수 있다(null).
  final DateTime? createdAt;

  factory BookmarkFolder.fromFirestore(String id, Map<String, dynamic> data) {
    return BookmarkFolder(
      id: id,
      name: (data['name'] as String?) ?? '',
      order: (data['order'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
