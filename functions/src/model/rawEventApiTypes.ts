/**
 * 한국관광공사_국문 관광정보 서비스_GW (KorService2) - 행사 관련 원본 응답 타입.
 *
 * KorWithService2(무장애 전용)와 별도의 활용신청/서비스키가 필요한 API입니다.
 * TourApiResponse<T> 제네릭은 rawTourApiTypes.ts의 것을 그대로 재사용합니다
 * (같은 TourAPI 계열이라 envelope 구조가 동일).
 */

/** searchFestival2 (행사정보 조회) item.
 * 목록 조회 시점에 eventstartdate/eventenddate가 이미 포함되어 있어,
 * KorWithService2처럼 별도 detailIntro2 호출 없이 날짜 정보를 바로 얻을 수 있음. */
export interface RawFestivalListItem {
  addr1?: string;
  addr2?: string;
  areacode?: string;
  cat1?: string;
  cat2?: string;
  cat3?: string;
  contentid: string;
  contenttypeid: string; // "15" 고정
  createdtime: string;
  eventstartdate: string; // YYYYMMDD
  eventenddate: string; // YYYYMMDD
  firstimage?: string;
  firstimage2?: string;
  cpyrhtDivCd?: string;
  mapx?: string;
  mapy?: string;
  mlevel?: string;
  modifiedtime: string;
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

/** detailCommon2 (공통정보 조회) item.
 * homepage/overview/telname 등 searchFestival2에 없는 상세 정보를 담당.
 * homepage는 종종 <a href="URL" target="_blank">텍스트</a> 형태의 HTML로 옴. */
export interface RawDetailCommonItem {
  contentid: string;
  contenttypeid: string;
  title: string;
  createdtime: string;
  modifiedtime: string;
  tel?: string;
  telname?: string;
  homepage?: string;
  overview?: string;
  firstimage?: string;
  firstimage2?: string;
  addr1?: string;
  addr2?: string;
  zipcode?: string;
  mapx?: string;
  mapy?: string;
  areacode?: string;
  sigungucode?: string;
  lDongRegnCd?: string;
  lDongSignguCd?: string;
  lclsSystm1?: string;
  lclsSystm2?: string;
  lclsSystm3?: string;
}
