/**
 * Firestore `events` 컬렉션 타입 및 TourAPI(KorService2) 원본 → Firestore 매핑.
 *
 * tourSpots(무장애 인증 콘텐츠)와 완전히 분리된 컬렉션입니다.
 * - 접근성 정보 없음 (KorService2는 접근성 데이터 자체가 없음)
 * - 홈 화면 "이번달 행사/축제 배너" 전용
 * - 조건탐색에서는 카테고리는 노출하되, 접근성 필터와는 배타적으로 처리
 *   (프론트에서: 접근성 필터가 하나라도 선택되면 "축제/행사" 카테고리는
 *   결과에서 제외 — 이 컬렉션엔 애초에 접근성 필드가 없기 때문)
 */
import { RawDetailCommonItem, RawFestivalListItem } from "./rawEventApiTypes";

export interface FirestoreEventBasicInfo {
  contentId: string;
  contentTypeId: string;
  title: string;
  addr1: string;
  addr2: string | null;
  zipcode: string | null;
  mapX: number | null;
  mapY: number | null;
  firstImage: string | null;
  firstImage2: string | null;
  eventStartDate: string; // YYYYMMDD
  eventEndDate: string; // YYYYMMDD
  tel: string | null;
  lDongRegnCd: string | null;
  lDongSignguCd: string | null;
  lclsSystm1: string | null;
  lclsSystm2: string | null;
  lclsSystm3: string | null;
  createdTime: string;
  modifiedTime: string;
}

export interface FirestoreEventCommonInfo {
  telName: string | null;
  homepage: string | null; // HTML 앵커에서 href만 추출한 순수 URL
  overview: string | null;
}

export interface FirestoreEventDoc {
  basic: FirestoreEventBasicInfo;
  common?: FirestoreEventCommonInfo;
  /** detailCommon2로 상세(홈페이지 등) 보강 완료 여부 */
  commonSynced: boolean;
}

function emptyToNull(v?: string | null): string | null {
  if (v === undefined || v === null) return null;
  return v === "" ? null : v;
}

function toNumberOrNull(v?: string | null): number | null {
  const s = emptyToNull(v);
  if (s === null) return null;
  const n = Number(s);
  return Number.isNaN(n) ? null : n;
}

/**
 * detailCommon2의 homepage 필드는 <a href="URL" target="_blank">텍스트</a> 형태의
 * HTML로 오는 경우와 순수 URL 문자열로 오는 경우가 섞여 있음.
 * href 속성값이 있으면 그것만 추출, 없으면 원본을 최대한 그대로 활용.
 */
export function extractHomepageUrl(raw?: string | null): string | null {
  const s = emptyToNull(raw);
  if (s === null) return null;

  const hrefMatch = s.match(/href\s*=\s*"([^"]+)"/i);
  if (hrefMatch) return hrefMatch[1];

  if (/^https?:\/\//i.test(s.trim())) return s.trim();

  // 알 수 없는 형식이면 버리지 않고 원본 그대로 보존 (수동 확인 여지)
  return s;
}

export function mapEventBasicInfo(raw: RawFestivalListItem): FirestoreEventBasicInfo {
  return {
    contentId: raw.contentid,
    contentTypeId: raw.contenttypeid,
    title: raw.title,
    addr1: raw.addr1 ?? "",
    addr2: emptyToNull(raw.addr2),
    zipcode: emptyToNull(raw.zipcode),
    mapX: toNumberOrNull(raw.mapx),
    mapY: toNumberOrNull(raw.mapy),
    firstImage: emptyToNull(raw.firstimage),
    firstImage2: emptyToNull(raw.firstimage2),
    eventStartDate: raw.eventstartdate,
    eventEndDate: raw.eventenddate,
    tel: emptyToNull(raw.tel),
    lDongRegnCd: emptyToNull(raw.lDongRegnCd),
    lDongSignguCd: emptyToNull(raw.lDongSignguCd),
    lclsSystm1: emptyToNull(raw.lclsSystm1),
    lclsSystm2: emptyToNull(raw.lclsSystm2),
    lclsSystm3: emptyToNull(raw.lclsSystm3),
    createdTime: raw.createdtime,
    modifiedTime: raw.modifiedtime,
  };
}

export function mapEventCommonInfo(raw: RawDetailCommonItem): FirestoreEventCommonInfo {
  return {
    telName: emptyToNull(raw.telname),
    homepage: extractHomepageUrl(raw.homepage),
    overview: emptyToNull(raw.overview),
  };
}
