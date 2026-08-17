/**
 * Stage 1: 기본정보 백필 (areaBasedSyncList2)
 *
 * 7개 콘텐츠 타입을 순서대로 페이징하며 전부 수집합니다.
 * 이 단계는 numOfRows=100으로 페이징하면 총 호출 수가 ~90회 정도라
 * 보통 하루 예산(900) 안에서 한 번에 끝납니다.
 *
 * 저장 시 accessibilitySynced / festivalSynced 플래그를 false로 초기화해서,
 * 다음 단계(접근성/축제)가 "아직 안 채운 문서"를 쿼리로 골라낼 수 있게 합니다.
 * (Firestore는 "필드가 없는 문서" 쿼리가 까다로워서, 명시적 boolean 플래그로
 * 대체하는 게 표준적인 방법입니다.)
 */
import { Firestore } from "firebase-admin/firestore";
import { config } from "./config";
import { DailyBudgetExceededError, TourApiClient } from "./tourApiClient";
import { BackfillProgress, saveProgress } from "./progress";
import { mapBasicInfo } from "../../functions/src/model";

export async function runBasicStage(db: Firestore, client: TourApiClient, progress: BackfillProgress): Promise<BackfillProgress> {
  const typeIds = config.contentTypeIds;

  for (let typeIdx = progress.basicContentTypeIndex; typeIdx < typeIds.length; typeIdx++) {
    const contentTypeId = typeIds[typeIdx];
    let pageNo = typeIdx === progress.basicContentTypeIndex ? progress.basicPageNo : 1;

    while (true) {
      let result;
      try {
        result = await client.fetchAreaBasedSyncList({
          contentTypeId,
          pageNo,
          numOfRows: config.basicSyncPageSize,
          showflag: "1",
        });
      } catch (e) {
        if (e instanceof DailyBudgetExceededError) {
          console.log(`[basic] 예산 초과. contentTypeId=${contentTypeId}, pageNo=${pageNo}에서 중단, 내일 이어서 진행.`);
          progress.basicContentTypeIndex = typeIdx;
          progress.basicPageNo = pageNo;
          await saveProgress(db, progress);
          return progress;
        }
        throw e;
      }

      if (result.items.length === 0) break;

      const batch = db.batch();
      for (const raw of result.items) {
        const basic = mapBasicInfo(raw);
        const docRef = db.collection(config.tourSpotsCollection).doc(basic.contentId);
        batch.set(
          docRef,
          {
            basic,
            accessibilitySynced: false,
            // 축제 타입이 아니면 애초에 필요 없으니 true로 둬서 다음 단계 대상에서 제외
            festivalSynced: basic.contentTypeId === "15" ? false : true,
          },
          { merge: true },
        );
      }
      await batch.commit();

      console.log(`[basic] contentTypeId=${contentTypeId} pageNo=${pageNo} → ${result.items.length}건 저장 (총 ${result.totalCount}건 중)`);

      const fetchedSoFar = pageNo * config.basicSyncPageSize;
      if (fetchedSoFar >= result.totalCount) break;
      pageNo++;
    }

    progress.basicContentTypeIndex = typeIdx + 1;
    progress.basicPageNo = 1;
    await saveProgress(db, progress);
  }

  progress.stage = "accessibility";
  await saveProgress(db, progress);
  console.log("[basic] 전체 완료 → accessibility 단계로 전환");
  return progress;
}
