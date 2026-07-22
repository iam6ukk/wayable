/**
 * 행사(축제/공연/행사) 백필 스크립트 진입점.
 * 실행: npx ts-node scripts/backfill-events/run.ts
 */
import { config } from "./config";
import { initFirebaseAdmin, loadProgress } from "./progress";
import { EventApiClient } from "./eventApiClient";
import { runListingStage } from "./syncListing";
import { runDetailCommonStage } from "./syncDetailCommon";

async function main() {
  const db = initFirebaseAdmin();
  const client = new EventApiClient();
  let progress = await loadProgress(db);

  console.log(`=== 행사 백필 시작 (현재 stage: ${progress.stage}) ===`);

  if (progress.stage === "listing") {
    progress = await runListingStage(db, client, progress);
  }
  if (progress.stage === "detailCommon") {
    progress = await runDetailCommonStage(db, client, progress);
  }

  if (progress.stage === "done") {
    console.log("=== 행사 백필 전체 완료! ===");
  } else {
    console.log(`=== 오늘은 여기까지 (stage: ${progress.stage}, 호출 ${client.getCallCount()}회 사용). 내일 다시 실행하세요. ===`);
  }

  console.log(`이번 실행 총 API 호출: ${client.getCallCount()} / ${config.dailyCallBudget}`);
  process.exit(0);
}

main().catch((e) => {
  console.error("행사 백필 스크립트 에러:", e);
  process.exit(1);
});
