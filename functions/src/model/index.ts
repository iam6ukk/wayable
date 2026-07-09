/**
 * Firestore `tourSpots` 컬렉션에 저장되는 문서 타입.
 *
 * 필드명은 Flutter 쪽 TourBasicInfo / TourAccessibilityInfo / FestivalIntroInfo의
 * toJson() 키와 정확히 일치시켰습니다. 여기가 안 맞으면 앱에서 fromFirestore()
 * 파싱이 깨지니, 두 프로젝트 중 하나를 고치면 반드시 같이 고쳐야 합니다.
 */

import { RawAccessibilityItem, RawFestivalIntroItem, RawTourSyncItem } from "./rawTourApiTypes";

/** tourSpots/{contentId} 문서의 기본 정보 파트 (TourBasicInfo와 대응) */
export interface FirestoreTourBasicInfo {
  contentId: string;
  contentTypeId: string;
  title: string;
  addr1: string;
  addr2: string | null;

  areaCode: string | null;
  sigunguCode: string | null;

  cat1: string | null;
  cat2: string | null;
  cat3: string | null;

  mapX: number | null;
  mapY: number | null;

  firstImage: string | null;
  firstImage2: string | null;
  cpyrhtDivCd: string | null;

  lDongRegnCd: string | null;
  lDongSignguCd: string | null;

  lclsSystm1: string | null;
  lclsSystm2: string | null;
  lclsSystm3: string | null;

  createdTime: string;
  modifiedTime: string;
  showFlag: number;

  tel: string | null;
  zipcode: string | null;
}

/** 지체장애 (PhysicalDisabilityInfo와 대응) */
export interface FirestorePhysicalDisabilityInfo {
  parking: string | null;
  publicTransport: string | null;
  route: string | null;
  ticketOffice: string | null;
  promotion: string | null;
  wheelchair: string | null;
  exit: string | null;
  elevator: string | null;
  restroom: string | null;
  auditorium: string | null;
  room: string | null;
  handicapEtc: string | null;
}

/** 시각장애 (VisualDisabilityInfo와 대응) */
export interface FirestoreVisualDisabilityInfo {
  braileBlock: string | null;
  helpDog: string | null;
  guideHuman: string | null;
  audioGuide: string | null;
  bigPrint: string | null;
  brailePromotion: string | null;
  guideSystem: string | null;
  blindHandicapEtc: string | null;
}

/** 청각장애 (HearingDisabilityInfo와 대응) */
export interface FirestoreHearingDisabilityInfo {
  signGuide: string | null;
  videoGuide: string | null;
  hearingRoom: string | null;
  hearingHandicapEtc: string | null;
}

/** 영유아가족 (InfantFamilyInfo와 대응) */
export interface FirestoreInfantFamilyInfo {
  stroller: string | null;
  lactationRoom: string | null;
  babySpareChair: string | null;
  infantsFamilyEtc: string | null;
}

/** tourSpots/{contentId} 문서의 접근성 정보 파트 (TourAccessibilityInfo와 대응) */
export interface FirestoreTourAccessibilityInfo {
  physical: FirestorePhysicalDisabilityInfo;
  visual: FirestoreVisualDisabilityInfo;
  hearing: FirestoreHearingDisabilityInfo;
  infantFamily: FirestoreInfantFamilyInfo;
}

/** tourSpots/{contentId} 문서의 축제 정보 파트 (FestivalIntroInfo와 대응, contentTypeId=15만 존재) */
export interface FirestoreFestivalIntroInfo {
  ageLimit: string | null;
  bookingPlace: string | null;
  discountInfo: string | null;
  eventEndDate: string | null;
  eventHomepage: string | null;
  eventPlace: string | null;
  eventStartDate: string | null;
  festivalGrade: string | null;
  festivalType: string | null;
  placeInfo: string | null;
  playTime: string | null;
  program: string | null;
  progressType: string | null;
  spendTime: string | null;
  sponsor1: string | null;
  sponsor1Tel: string | null;
  sponsor2: string | null;
  sponsor2Tel: string | null;
  subEvent: string | null;
  useTimeFestival: string | null;
}

/**
 * Firestore tourSpots/{contentId} 최종 문서 형태.
 * basic은 항상 존재, accessibility/festival은 배치에서 병합(merge) 저장.
 */
export interface FirestoreTourSpotDoc {
  basic: FirestoreTourBasicInfo;
  accessibility?: FirestoreTourAccessibilityInfo;
  festival?: FirestoreFestivalIntroInfo; // contentTypeId === "15"일 때만 존재
}

// ---------------------------------------------------------------------------
// 변환 함수: TourAPI 원본 응답 → Firestore 저장 타입
// ---------------------------------------------------------------------------

/** 빈 문자열/undefined를 null로 정규화 (Dart emptyToNull과 동일한 규칙) */
function emptyToNull(v: string | undefined | null): string | null {
  if (v === undefined || v === null) return null;
  return v === "" ? null : v;
}

function toNumberOrNull(v: string | undefined | null): number | null {
  const s = emptyToNull(v);
  if (s === null) return null;
  const n = Number(s);
  return Number.isNaN(n) ? null : n;
}

export function mapBasicInfo(raw: RawTourSyncItem): FirestoreTourBasicInfo {
  return {
    contentId: raw.contentid,
    contentTypeId: raw.contenttypeid,
    title: raw.title,
    addr1: raw.addr1 ?? "",
    addr2: emptyToNull(raw.addr2),
    areaCode: emptyToNull(raw.areacode),
    sigunguCode: emptyToNull(raw.sigungucode),
    cat1: emptyToNull(raw.cat1),
    cat2: emptyToNull(raw.cat2),
    cat3: emptyToNull(raw.cat3),
    mapX: toNumberOrNull(raw.mapx),
    mapY: toNumberOrNull(raw.mapy),
    firstImage: emptyToNull(raw.firstimage),
    firstImage2: emptyToNull(raw.firstimage2),
    cpyrhtDivCd: emptyToNull(raw.cpyrhtDivCd),
    lDongRegnCd: emptyToNull(raw.lDongRegnCd),
    lDongSignguCd: emptyToNull(raw.lDongSignguCd),
    lclsSystm1: emptyToNull(raw.lclsSystm1),
    lclsSystm2: emptyToNull(raw.lclsSystm2),
    lclsSystm3: emptyToNull(raw.lclsSystm3),
    createdTime: raw.createdtime,
    modifiedTime: raw.modifiedtime,
    showFlag: Number(raw.showflag),
    tel: emptyToNull(raw.tel),
    zipcode: emptyToNull(raw.zipcode),
  };
}

export function mapAccessibilityInfo(raw: RawAccessibilityItem): FirestoreTourAccessibilityInfo {
  return {
    physical: {
      parking: emptyToNull(raw.parking),
      publicTransport: emptyToNull(raw.publictransport),
      route: emptyToNull(raw.route),
      ticketOffice: emptyToNull(raw.ticketoffice),
      promotion: emptyToNull(raw.promotion),
      wheelchair: emptyToNull(raw.wheelchair),
      exit: emptyToNull(raw.exit),
      elevator: emptyToNull(raw.elevator),
      restroom: emptyToNull(raw.restroom),
      auditorium: emptyToNull(raw.auditorium),
      room: emptyToNull(raw.room),
      handicapEtc: emptyToNull(raw.handicapetc),
    },
    visual: {
      braileBlock: emptyToNull(raw.braileblock),
      helpDog: emptyToNull(raw.helpdog),
      guideHuman: emptyToNull(raw.guidehuman),
      audioGuide: emptyToNull(raw.audioguide),
      bigPrint: emptyToNull(raw.bigprint),
      brailePromotion: emptyToNull(raw.brailepromotion),
      guideSystem: emptyToNull(raw.guidesystem),
      blindHandicapEtc: emptyToNull(raw.blindhandicapetc),
    },
    hearing: {
      signGuide: emptyToNull(raw.signguide),
      videoGuide: emptyToNull(raw.videoguide),
      hearingRoom: emptyToNull(raw.hearingroom),
      hearingHandicapEtc: emptyToNull(raw.hearinghandicapetc),
    },
    infantFamily: {
      stroller: emptyToNull(raw.stroller),
      lactationRoom: emptyToNull(raw.lactationroom),
      babySpareChair: emptyToNull(raw.babysparechair),
      infantsFamilyEtc: emptyToNull(raw.infantsfamilyetc),
    },
  };
}

export function mapFestivalIntroInfo(raw: RawFestivalIntroItem): FirestoreFestivalIntroInfo {
  return {
    ageLimit: emptyToNull(raw.agelimit),
    bookingPlace: emptyToNull(raw.bookingplace),
    discountInfo: emptyToNull(raw.discountinfofestival),
    eventEndDate: emptyToNull(raw.eventenddate),
    eventHomepage: emptyToNull(raw.eventhomepage),
    eventPlace: emptyToNull(raw.eventplace),
    eventStartDate: emptyToNull(raw.eventstartdate),
    festivalGrade: emptyToNull(raw.festivalgrade),
    festivalType: emptyToNull(raw.festivaltype),
    placeInfo: emptyToNull(raw.placeinfo),
    playTime: emptyToNull(raw.playtime),
    program: emptyToNull(raw.program),
    progressType: emptyToNull(raw.progresstype),
    spendTime: emptyToNull(raw.spendtimefestival),
    sponsor1: emptyToNull(raw.sponsor1),
    sponsor1Tel: emptyToNull(raw.sponsor1tel),
    sponsor2: emptyToNull(raw.sponsor2),
    sponsor2Tel: emptyToNull(raw.sponsor2tel),
    subEvent: emptyToNull(raw.subevent),
    useTimeFestival: emptyToNull(raw.usetimefestival),
  };
}
