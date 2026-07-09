/**
 * Asia/Seoul(KST) 기준 날짜 유틸.
 *
 * Cloud Functions 실행 서버는 UTC 기준이라, JS의 Date 객체를 그냥
 * getFullYear()/getMonth() 등으로 다루면 자정 근처에 날짜가 하루 밀리는
 * 버그가 생길 수 있습니다. Intl.DateTimeFormat으로 타임존을 명시해서 우회합니다.
 */

const KST_TIME_ZONE = "Asia/Seoul";

/** Date 객체를 KST 기준 YYYYMMDD 문자열로 변환 (TourAPI modifiedtime 파라미터 형식) */
export function toKstYyyymmdd(date: Date): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: KST_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  // en-CA 로케일은 YYYY-MM-DD 형식으로 나옴 → 하이픈만 제거
  return formatter.format(date).replace(/-/g, "");
}

/** YYYYMMDD 문자열을 KST 자정 기준 Date로 파싱 */
export function parseYyyymmdd(s: string): Date {
  const y = Number(s.substring(0, 4));
  const m = Number(s.substring(4, 6));
  const d = Number(s.substring(6, 8));
  // KST 자정 = UTC 기준 전날 15:00. 날짜 "차이" 계산용이라 정확한 시각보다
  // 날짜 단위 연산이 안전하게 되는 게 중요 → UTC 기준으로 만들어서 dayjs 없이도
  // 날짜 덧셈/뺄셈이 타임존 영향 안 받게 처리.
  return new Date(Date.UTC(y, m - 1, d));
}

/** YYYYMMDD 문자열에 n일을 더한 새로운 YYYYMMDD 문자열 반환 */
export function addDaysToYyyymmdd(s: string, days: number): string {
  const date = parseYyyymmdd(s);
  date.setUTCDate(date.getUTCDate() + days);
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

/** a가 b보다 이전 날짜인지 (문자열 비교로 충분 — YYYYMMDD는 사전순=날짜순) */
export function isBefore(a: string, b: string): boolean {
  return a < b;
}
