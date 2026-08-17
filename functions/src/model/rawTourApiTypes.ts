/**
 * TourAPI (KorWithService2) 원본 응답 타입 정의.
 *
 * 여기 정의된 필드명은 TourAPI가 실제로 내려주는 키 그대로입니다
 * (lowercase, lDongRegnCd처럼 camelCase 섞인 것도 API 원본 그대로 유지).
 * Firestore에 저장할 때는 이 타입을 FirestoreTour* 타입으로 변환해서 씁니다.
 *
 * 참고: TourAPI 응답 필드는 항상 string으로 내려오는 경우가 많음
 * (숫자/불린도 문자열). 여기서는 원본 계약을 최대한 그대로 반영.
 */

/** areaBasedSyncList2 (무장애 여행정보 동기화 목록 조회) item */
export interface RawTourSyncItem {
  addr1?: string;
  addr2?: string;
  areacode?: string;
  cat1?: string;
  cat2?: string;
  cat3?: string;
  contentid: string;
  contenttypeid: string;
  createdtime: string;
  firstimage?: string;
  firstimage2?: string;
  cpyrhtDivCd?: string;
  mapx?: string;
  mapy?: string;
  mlevel?: string;
  modifiedtime: string;
  showflag: string; // "1" | "0"
  sigungucode?: string;
  tel?: string;
  title: string;
  zipcode?: string;
  lDongRegnCd?: string;
  lDongSignguCd?: string;
  lclsSystm1?: string;
  lclsSystm2?: string;
  lclsSystm3?: string;
}

/** detailWithTour2 (무장애여행 조회) item */
export interface RawAccessibilityItem {
  contentid: string;

  // 지체장애
  parking?: string;
  publictransport?: string;
  route?: string;
  ticketoffice?: string;
  promotion?: string;
  wheelchair?: string;
  exit?: string;
  elevator?: string;
  restroom?: string;
  auditorium?: string;
  room?: string;
  handicapetc?: string;

  // 시각장애
  braileblock?: string;
  helpdog?: string;
  guidehuman?: string;
  audioguide?: string;
  bigprint?: string;
  brailepromotion?: string;
  guidesystem?: string;
  blindhandicapetc?: string;

  // 청각장애
  signguide?: string;
  videoguide?: string;
  hearingroom?: string;
  hearinghandicapetc?: string;

  // 영유아가족
  stroller?: string;
  lactationroom?: string;
  babysparechair?: string;
  infantsfamilyetc?: string;
}

/** detailIntro2 (소개정보 조회) item — contentTypeId=15 (행사/공연/축제) 요청 시 응답 */
export interface RawFestivalIntroItem {
  contentid: string;
  contenttypeid: string;

  agelimit?: string;
  bookingplace?: string;
  discountinfofestival?: string;
  eventenddate?: string;
  eventhomepage?: string;
  eventplace?: string;
  eventstartdate?: string;
  festivalgrade?: string;
  festivaltype?: string;
  placeinfo?: string;
  playtime?: string;
  program?: string;
  progresstype?: string;
  spendtimefestival?: string;
  sponsor1?: string;
  sponsor1tel?: string;
  sponsor2?: string;
  sponsor2tel?: string;
  subevent?: string;
  usetimefestival?: string;
}

/** TourAPI 공통 응답 envelope (_type=json 요청 기준) */
export interface TourApiResponse<T> {
  response: {
    header: {
      resultCode: string;
      resultMsg: string;
    };
    body: {
      items: {
        // totalCount=0이면 TourAPI가 items를 "" (빈 문자열)로 내려주는 경우가 있어서
        // 호출부에서 반드시 방어적으로 체크해야 함.
        item?: T | T[];
      };
      numOfRows: number;
      pageNo: number;
      totalCount: number;
    };
  };
}

/** contentTypeId 상수 (무장애여행 서비스 7종) */
export const TourContentTypeId = {
  TOURIST_SPOT: "12", // 관광지
  CULTURE_FACILITY: "14", // 문화시설
  FESTIVAL: "15", // 행사/공연/축제
  LEPORTS: "28", // 레포츠
  LODGING: "32", // 숙박
  SHOPPING: "38", // 쇼핑
  RESTAURANT: "39", // 음식점
} as const;

export type TourContentTypeIdValue = (typeof TourContentTypeId)[keyof typeof TourContentTypeId];
