import 'package:flutter/material.dart';

/// 사용자가 선택하는 접근성 지원 대분류.
/// AppUser.accessibilityProfiles(Firestore)에는 `.name` 값으로 저장된다.
enum AccessibilityProfile {
  physicalAssist, // 지체장애 필드군 전체
  hearingAssist, // 청각장애 필드군
  visionAssist, // 시각장애 필드군
  strollerCompanion, // 영유아가족 필드군
  seniorCompanion, // 지체장애 필드군 중 일부 재사용
}

extension AccessibilityProfileX on AccessibilityProfile {
  String get label => switch (this) {
    AccessibilityProfile.physicalAssist => '지체장애 보조',
    AccessibilityProfile.hearingAssist => '청각장애 보조',
    AccessibilityProfile.visionAssist => '시각장애 보조',
    AccessibilityProfile.strollerCompanion => '유모차동반',
    AccessibilityProfile.seniorCompanion => '고령자 동반',
  };

  IconData get icon => switch (this) {
    AccessibilityProfile.physicalAssist => Icons.accessible,
    AccessibilityProfile.hearingAssist => Icons.hearing_disabled,
    AccessibilityProfile.visionAssist => Icons.visibility_off,
    AccessibilityProfile.strollerCompanion => Icons.child_care,
    AccessibilityProfile.seniorCompanion => Icons.elderly,
  };
}
