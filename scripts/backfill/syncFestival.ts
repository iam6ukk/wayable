/**
 * Stage 3: 축제 소개정보 백필 (detailIntro2, contentTypeId=15 전용)
 *
 * syncBasic 단계에서 15번 타입이 아닌 문서는 festivalSynced=true로
 * 이미 처리해뒀기 때문에, 여기 쿼리에 걸리는 건 축제/공연/행사뿐입니다.
 *
 * accessibility 단계와 동일하게, 재시도까지 실패한 건은 스킵(내일 재시도),
 * 연속 실패가 많으면 오늘은 안전하게 중단합니다.
 */
import { Firestore } from "firebase-admin/firestore";
import { config } from "./config";
import { DailyBudgetExceededError, TourApiCallFailedError, TourApiClient } from "./tourApiClient";
import { BackfillProgress, saveProgress } from "./progress";
import { mapFestivalIntroInfo } from "../../functions/src/model";

const QUERY_BATCH_SIZE = 50;
const MAX_CONSECUTIVE_FAILURES = 8;

export async function runFestivalStage(db: Firestore, client: TourApiClient, progress: BackfillProgress): Promise<BackfillProgress> {
  let consecutiveFailures = 0;

  while (true) {
    const snap = await db.collection(config.tourSpotsCollection).where("festivalSynced", "==", false).limit(QUERY_BATCH_SIZE).get();

    if (snap.empty) break;

    for (const doc of snap.docs) {
      const contentId = doc.id;
      let raw;
      try {
        raw = await client.fetchFestivalIntro(contentId);
        consecutiveFailures = 0;
      } catch (e) {
        if (e instanceof DailyBudgetExceededError) {
          console.log(`[festival] 예산 초과. contentId=${contentId}에서 중단, 내일 이어서 진행.`);
          await saveProgress(db, progress);
          return progress;
        }

        if (e instanceof TourApiCallFailedError) {
          consecutiveFailures++;
          console.warn(
            `[festival] contentId=${contentId} 재시도 끝까지 실패, 스킵 (연속 실패 ${consecutiveFailures}회). 원인: ${
              (e.cause as Error)?.message ?? e.message
            }`,
          );

          if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            console.error(`[festival] 연속 ${MAX_CONSECUTIVE_FAILURES}회 실패 — TourAPI 서버 상태가 안 좋은 것 같습니다. 오늘은 여기서 중단합니다.`);
            await saveProgress(db, progress);
            return progress;
          }
          continue;
        }

        throw e;
      }

      if (raw === null) {
        await doc.ref.set({ festivalSynced: true }, { merge: true });
        continue;
      }

      const festival = mapFestivalIntroInfo(raw);
      await doc.ref.set({ festival, festivalSynced: true }, { merge: true });
    }

    console.log(`[festival] ${snap.size}건 처리 (누적 호출 ${client.getCallCount()}회)`);
  }

  progress.stage = "done";
  await saveProgress(db, progress);
  console.log("[festival] 전체 완료 → 백필 종료 (stage=done)");
  return progress;
}
