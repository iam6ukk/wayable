/**
 * Stage 2: 접근성 상세정보 백필 (detailWithTour2)
 *
 * accessibilitySynced === false 인 문서만 반복 쿼리해서 처리합니다.
 * 처리 즉시 true로 바꾸므로, 예산이 초과돼서 중간에 멈춰도 다음 실행 때
 * 자동으로 "아직 안 한 것"부터 이어집니다 (별도 커서 관리 불필요).
 *
 * 재시도까지 다 실패한 건(TourApiCallFailedError)은 synced=false로 그대로
 * 남겨두고 다음 항목으로 넘어갑니다 → 내일 자동으로 재시도됨.
 * 단, 연속으로 계속 실패하면(서버 자체가 다운된 상황일 수 있음) 오늘은
 * 여기서 접고 안전하게 종료합니다 (예산 다 쓴 것과 동일하게 취급).
 */
import { Firestore } from "firebase-admin/firestore";
import { config } from "./config";
import { DailyBudgetExceededError, TourApiCallFailedError, TourApiClient } from "./tourApiClient";
import { BackfillProgress, saveProgress } from "./progress";
import { mapAccessibilityInfo } from "../../functions/src/model";

const QUERY_BATCH_SIZE = 50; // 한 번에 읽어올 문서 수 (Firestore read, API call과 무관)

/** 이 횟수만큼 연속으로 실패하면 "오늘은 서버 상태가 안 좋다"고 보고 중단 */
const MAX_CONSECUTIVE_FAILURES = 8;

export async function runAccessibilityStage(db: Firestore, client: TourApiClient, progress: BackfillProgress): Promise<BackfillProgress> {
  let consecutiveFailures = 0;

  while (true) {
    const snap = await db.collection(config.tourSpotsCollection).where("accessibilitySynced", "==", false).limit(QUERY_BATCH_SIZE).get();

    if (snap.empty) break;

    for (const doc of snap.docs) {
      const contentId = doc.id;
      let raw;
      try {
        raw = await client.fetchAccessibility(contentId);
        consecutiveFailures = 0; // 성공하면 리셋
      } catch (e) {
        if (e instanceof DailyBudgetExceededError) {
          console.log(`[accessibility] 예산 초과. contentId=${contentId}에서 중단, 내일 이어서 진행.`);
          await saveProgress(db, progress);
          return progress;
        }

        if (e instanceof TourApiCallFailedError) {
          consecutiveFailures++;
          console.warn(
            `[accessibility] contentId=${contentId} 재시도 끝까지 실패, 스킵 (연속 실패 ${consecutiveFailures}회). 원인: ${
              (e.cause as Error)?.message ?? e.message
            }`,
          );

          if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            console.error(
              `[accessibility] 연속 ${MAX_CONSECUTIVE_FAILURES}회 실패 — TourAPI 서버 상태가 안 좋은 것 같습니다. 오늘은 여기서 중단합니다.`,
            );
            await saveProgress(db, progress);
            return progress;
          }
          continue; // synced=false로 남겨두고 다음 항목으로
        }

        throw e; // 그 외 예상 못 한 에러는 그대로 올려서 스크립트 중단 (원인 파악 필요)
      }

      if (raw === null) {
        // 데이터 없음(NODATA) — 그냥 synced 처리하고 넘어감
        await doc.ref.set({ accessibilitySynced: true }, { merge: true });
        continue;
      }

      const accessibility = mapAccessibilityInfo(raw);
      await doc.ref.set({ accessibility, accessibilitySynced: true }, { merge: true });
    }

    console.log(`[accessibility] ${snap.size}건 처리 (누적 호출 ${client.getCallCount()}회)`);
  }

  progress.stage = "festival";
  await saveProgress(db, progress);
  console.log("[accessibility] 전체 완료 → festival 단계로 전환");
  return progress;
}
