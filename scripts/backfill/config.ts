/**
 * 백필 스크립트 공통 설정.
 *
 * 개발계정 트래픽 한도(하루 1,000건, 이 서비스키의 모든 오퍼레이션 공유)를
 * 고려해서 하루 실행량을 여유 있게 900건으로 캡을 둡니다.
 * (다른 테스트 호출 여지 100건 남겨두는 버퍼)
 */
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../.env.backfill") });

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) {
    throw new Error(`환경변수 ${key} 가 없습니다. .env.backfill 파일을 프로젝트 루트에 만들어주세요.`);
  }
  return v;
}

export const config = {
  tourApiServiceKey: requireEnv("TOUR_API_SERVICE_KEY"), // Decoding key
  firebaseServiceAccountPath: requireEnv("FIREBASE_SERVICE_ACCOUNT_PATH"),

  /** 오늘 하루 이 스크립트가 쓸 수 있는 최대 호출 수 (개발계정 1,000건 중 버퍼 남김) */
  dailyCallBudget: 900,

  /** TourAPI 호출 사이 딜레이 (ms). 초당 과도한 호출 방지용 안전장치. */
  callDelayMs: 150,

  /** areaBasedSyncList2 페이징 시 한 페이지당 건수 (많을수록 basic 단계 호출 수 절약) */
  basicSyncPageSize: 100,

  mobileOs: "ETC",
  mobileApp: "WayAble",

  baseUrl: "https://apis.data.go.kr/B551011/KorWithService2",

  /** 무장애여행 서비스 7개 콘텐츠 타입 */
  contentTypeIds: ["12", "14", "15", "28", "32", "38", "39"] as const,

  /** Firestore 진행상황 문서 경로 */
  progressDocPath: "_syncMeta/backfillProgress",

  tourSpotsCollection: "tourSpots",
};
