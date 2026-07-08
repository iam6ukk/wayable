/**
 * 백필 스크립트 진입점.
 *
 * 실행: npx ts-node scripts/backfill/run.ts
 * (매일 1회 실행 — Windows 작업 스케줄러에 등록해두면 손 안 대고 돌아갑니다)
 *
 * stage가 "done"이 될 때까지 매일 실행하면 되고, 하루 예산을 다 쓰면
 * 자동으로 안전하게 멈추고 진행상황을 Firestore에 남깁니다.
 */
import { config } from "./config";
import { initFirebaseAdmin, loadProgress } from "./progress";
import { TourApiClient } from "./tourApiClient";
import { runBasicStage } from "./syncBasic";
import { runAccessibilityStage } from "./syncAccessibility";
import { runFestivalStage } from "./syncFestival";

async function main() {
  const db = initFirebaseAdmin();
  const client = new TourApiClient();
  let progress = await loadProgress(db);

  console.log(`=== 백필 시작 (현재 stage: ${progress.stage}) ===`);

  if (progress.stage === "basic") {
    progress = await runBasicStage(db, client, progress);
  }
  if (progress.stage === "accessibility") {
    progress = await runAccessibilityStage(db, client, progress);
  }
  if (progress.stage === "festival") {
    progress = await runFestivalStage(db, client, progress);
  }

  if (progress.stage === "done") {
    console.log("=== 전체 백필 완료! ===");
  } else {
    console.log(`=== 오늘은 여기까지 (stage: ${progress.stage}, 호출 ${client.getCallCount()}회 사용). 내일 다시 실행하세요. ===`);
  }

  console.log(`이번 실행 총 API 호출: ${client.getCallCount()} / ${config.dailyCallBudget}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("백필 스크립트 에러:", e);
  process.exit(1);
});
