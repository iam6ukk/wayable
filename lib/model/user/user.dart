import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? nickname;
  final String? email;
  final String? provider; // 로그인 서비스
  final List<String> accessibilityProfiles; // 접근성 프로필 (대분류)
  final List<String> accessibilityFields; // 상세 무장애 정보 항목
  final DateTime createdAt; // 생성일

  AppUser({
    required this.uid,
    this.nickname,
    this.email,
    required this.provider,
    this.accessibilityProfiles = const [],
    this.accessibilityFields = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Firestore에 저장할 Map으로 변환 (Java의 toJson() 같은 역할)
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'nickname': nickname,
      'email': email,
      'provider': provider,
      'accessibilityProfiles': accessibilityProfiles,
      'accessibilityFields': accessibilityFields,
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
      accessibilityProfiles: List<String>.from(
        data['accessibilityProfiles'] ?? [],
      ),
      accessibilityFields: List<String>.from(
        data['accessibilityFields'] ?? [],
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
    List<String>? accessibilityProfiles,
    List<String>? accessibilityFields,
  }) {
    return AppUser(
      uid: uid,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      provider: provider,
      accessibilityProfiles:
          accessibilityProfiles ?? this.accessibilityProfiles,
      accessibilityFields: accessibilityFields ?? this.accessibilityFields,
      createdAt: createdAt,
    );
  }
}
