import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? nickname;
  final String? email;
  final String? provider; // 로그인 서비스

  /// 대분류명(AccessibilityProfile.name) -> 그 대분류에서 개별 선택한
  /// 상세 필드명(AccessibilityField.name) 목록. 빈 리스트 = 그 대분류는 "전체" 선택.
  /// 대분류별로 분리해서 저장해야 한다 — 지체장애/고령자동반처럼 필드가 겹치는
  /// 대분류가 있어서, 하나의 flat 리스트로 합쳐버리면 어느 대분류의 선택이었는지
  /// 복원할 수 없어진다 (accessibility_detail_screen.dart 참고).
  final Map<String, List<String>> accessibilityFieldsByProfile;

  final DateTime createdAt; // 생성일

  AppUser({
    required this.uid,
    this.nickname,
    this.email,
    required this.provider,
    this.accessibilityFieldsByProfile = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 선택된 접근성 프로필(대분류) 이름 목록. accessibilityFieldsByProfile의 키가
  /// 곧 "선택된 대분류"라서 별도 필드로 중복 저장하지 않고 여기서 파생시킨다.
  List<String> get accessibilityProfiles =>
      accessibilityFieldsByProfile.keys.toList();

  // Firestore에 저장할 Map으로 변환 (Java의 toJson() 같은 역할)
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'nickname': nickname,
      'email': email,
      'provider': provider,
      'accessibilityFieldsByProfile': accessibilityFieldsByProfile,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Firestore 문서 → AppUser로 변환 (Java의 fromJson() 같은 역할)
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: data['uid'] as String,
      nickname: data['nickname'] as String?,
      email: data['email'] as String?,
      provider: data['provider'] as String? ?? 'unknown',
      accessibilityFieldsByProfile:
          (data['accessibilityFieldsByProfile'] as Map<String, dynamic>? ?? {})
              .map(
                (key, value) => MapEntry(key, List<String>.from(value as List)),
              ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // 일부 필드만 바꾼 새 객체 반환 (copyWith)
  AppUser copyWith({
    String? nickname,
    String? email,
    Map<String, List<String>>? accessibilityFieldsByProfile,
  }) {
    return AppUser(
      uid: uid,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      provider: provider,
      accessibilityFieldsByProfile:
          accessibilityFieldsByProfile ?? this.accessibilityFieldsByProfile,
      createdAt: createdAt,
    );
  }
}
