import 'accessibility_field.dart';
import 'accessibility_profile.dart';

/// AccessibilityProfile(대분류) -> 상세 설정에서 보여줄 AccessibilityField 목록.
class AccessibilityFieldMapping {
  const AccessibilityFieldMapping._();

  static const Map<AccessibilityProfile, List<AccessibilityField>> mapping = {
    AccessibilityProfile.physicalAssist: [
      AccessibilityField.parking,
      AccessibilityField.publicTransport,
      AccessibilityField.route,
      AccessibilityField.ticketOffice,
      AccessibilityField.promotion,
      AccessibilityField.wheelchair,
      AccessibilityField.exit,
      AccessibilityField.elevator,
      AccessibilityField.restroom,
      AccessibilityField.auditorium,
      AccessibilityField.room,
      AccessibilityField.handicapEtc,
    ],
    AccessibilityProfile.hearingAssist: [
      AccessibilityField.signGuide,
      AccessibilityField.videoGuide,
      AccessibilityField.hearingRoom,
      AccessibilityField.hearingHandicapEtc,
    ],
    AccessibilityProfile.visionAssist: [
      AccessibilityField.braileBlock,
      AccessibilityField.helpDog,
      AccessibilityField.guideHuman,
      AccessibilityField.audioGuide,
      AccessibilityField.bigPrint,
      AccessibilityField.brailePromotion,
      AccessibilityField.guideSystem,
      AccessibilityField.blindHandicapEtc,
    ],
    AccessibilityProfile.infantFamily: [
      AccessibilityField.stroller,
      AccessibilityField.lactationRoom,
      AccessibilityField.babySpareChair,
      AccessibilityField.infantsFamilyEtc,
    ],
    AccessibilityProfile.seniorCompanion: [
      AccessibilityField.parking,
      AccessibilityField.route,
      AccessibilityField.wheelchair,
      AccessibilityField.exit,
      AccessibilityField.elevator,
      AccessibilityField.restroom,
    ],
  };
}
