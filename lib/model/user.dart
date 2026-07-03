import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? nickname;
  final String? email;
  final String? provider; // 로그인 서비스
  final List<String> accessibilityProfiles; // 접근성 프로필
  final String? areaCode; // 지역코드
  final String? areaName; // "서울"
  final String? sigunguCode; // 시군구코드
  final String? sigunguName; // "강남구"
  final DateTime createdAt; // 생성일

  AppUser({
    required this.uid,
    this.nickname,
    this.email,
    required this.provider,
    this.accessibilityProfiles = const [],
    this.areaCode,
    this.areaName,
    this.sigunguCode,
    this.sigunguName,
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
      'areaCode': areaCode,
      'areaName': areaName,
      'sigunguCode': sigunguCode,
      'sigunguName': sigunguName,
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
      areaCode: data['areaCode'] as String?,
      areaName: data['areaName'] as String?,
      sigunguCode: data['sigunguCode'] as String?,
      sigunguName: data['sigunguName'] as String?,
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
    String? areaCode,
    String? areaName,
    String? sigunguCode,
    String? sigunguName,
  }) {
    return AppUser(
      uid: uid,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      provider: provider,
      accessibilityProfiles:
          accessibilityProfiles ?? this.accessibilityProfiles,
      areaCode: areaCode ?? this.areaCode,
      areaName: areaName ?? this.areaName,
      sigunguCode: sigunguCode ?? this.sigunguCode,
      sigunguName: sigunguName ?? this.sigunguName,
      createdAt: createdAt,
    );
  }
}
