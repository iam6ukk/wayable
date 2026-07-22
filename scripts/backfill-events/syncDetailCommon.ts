/**
 * Stage 2: 행사 공통정보(홈페이지 등) 백필 (detailCommon2)
 *
 * commonSynced === false 인 문서만 반복 쿼리해서 처리.
 * scripts/backfill/syncAccessibility.ts와 동일한 재시도/스킵/연속실패 안전장치 패턴.
 */
import { Firestore } from "firebase-admin/firestore";
import { config } from "./config";
import { DailyBudgetExceededError, TourApiCallFailedError, EventApiClient } from "./eventApiClient";
import { BackfillProgress, saveProgress } from "./progress";
import { mapEventCommonInfo } from "../../functions/src/model/eventTypes";

const QUERY_BATCH_SIZE = 50;
const MAX_CONSECUTIVE_FAILURES = 8;

export async function runDetailCommonStage(db: Firestore, client: EventApiClient, progress: BackfillProgress): Promise<BackfillProgress> {
  let consecutiveFailures = 0;

  while (true) {
    const snap = await db.collection(config.eventsCollection).where("commonSynced", "==", false).limit(QUERY_BATCH_SIZE).get();

    if (snap.empty) break;

    for (const doc of snap.docs) {
      const contentId = doc.id;
      let raw;
      try {
        raw = await client.fetchDetailCommon(contentId);
        consecutiveFailures = 0;
      } catch (e) {
        if (e instanceof DailyBudgetExceededError) {
          console.log(`[detailCommon] 예산 초과. contentId=${contentId}에서 중단, 내일 이어서 진행.`);
          await saveProgress(db, progress);
          return progress;
        }

        if (e instanceof TourApiCallFailedError) {
          consecutiveFailures++;
          console.warn(`[detailCommon] contentId=${contentId} 재시도 끝까지 실패, 스킵 (연속 실패 ${consecutiveFailures}회)`);
          if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            console.error(`[detailCommon] 연속 ${MAX_CONSECUTIVE_FAILURES}회 실패 — 오늘은 여기서 중단합니다.`);
            await saveProgress(db, progress);
            return progress;
          }
          continue;
        }

        throw e;
      }

      if (raw === null) {
        await doc.ref.set({ commonSynced: true }, { merge: true });
        continue;
      }

      const common = mapEventCommonInfo(raw);
      await doc.ref.set({ common, commonSynced: true }, { merge: true });
    }

    console.log(`[detailCommon] ${snap.size}건 처리 (누적 호출 ${client.getCallCount()}회)`);
  }

  progress.stage = "done";
  await saveProgress(db, progress);
  console.log("[detailCommon] 전체 완료 → 행사 백필 종료 (stage=done)");
  return progress;
}
