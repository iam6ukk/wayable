/**
 * 행사(축제/공연/행사) 백필 스크립트 설정.
 *
 * KorWithService2(무장애)와는 별도의 활용신청/서비스키를 쓰는 API라서
 * 트래픽 예산도 완전히 독립적입니다 (기존 백필/델타싱크와 경쟁 없음).
 */
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../.env.backfill-events") });

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) {
    throw new Error(`환경변수 ${key} 가 없습니다. .env.backfill-events 파일을 프로젝트 루트에 만들어주세요.`);
  }
  return v;
}

export const config = {
  serviceKey: requireEnv("KORSERVICE_API_SERVICE_KEY"), // KorService2용 Decoding key
  firebaseServiceAccountPath: requireEnv("FIREBASE_SERVICE_ACCOUNT_PATH"),

  dailyCallBudget: 900,
  callDelayMs: 150,

  pageSize: 100,

  mobileOs: "ETC",
  mobileApp: "WayAble",

  baseUrl: "https://apis.data.go.kr/B551011/KorService2",

  /**
   * "오늘로부터 며칠 전"까지의 행사를 포함할지.
   * 음수로 과거 방향 여유를 둬서, 오늘 기준 이미 시작했지만 아직 안 끝난
   * 다일간 행사도 놓치지 않게 함. searchFestival2는 eventStartDate 이후
   * 시작(또는 진행 중)인 행사를 반환하는 방식이라, 너무 타이트하게 잡으면
   * 진행 중인 행사가 누락될 수 있음.
   */
  eventStartDateBufferDays: -7,

  progressDocPath: "_syncMeta/eventsBackfillProgress",
  eventsCollection: "events",
};
