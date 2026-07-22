/**
 * Stage 1: 행사 목록 백필 (searchFestival2)
 *
 * eventStartDate = 오늘 - 7일(버퍼) 기준으로 "현재 진행중이거나 예정인" 행사만
 * 가져옵니다. searchFestival2 응답에 이미 eventstartdate/eventenddate가
 * 포함되어 있어 별도 소개정보 호출이 필요 없습니다 (KorWithService2와의 차이점).
 */
import { Firestore } from "firebase-admin/firestore";
import { config } from "./config";
import { DailyBudgetExceededError, EventApiClient } from "./eventApiClient";
import { BackfillProgress, saveProgress } from "./progress";
import { mapEventBasicInfo } from "../../functions/src/model/eventTypes";
import { addDaysToYyyymmdd, toKstYyyymmdd } from "../../functions/src/lib/dateUtils";

export async function runListingStage(db: Firestore, client: EventApiClient, progress: BackfillProgress): Promise<BackfillProgress> {
  const eventStartDate = addDaysToYyyymmdd(toKstYyyymmdd(new Date()), config.eventStartDateBufferDays);

  let pageNo = progress.listingPageNo;

  while (true) {
    let result;
    try {
      result = await client.searchFestival({
        eventStartDate,
        pageNo,
        numOfRows: config.pageSize,
      });
    } catch (e) {
      if (e instanceof DailyBudgetExceededError) {
        console.log(`[listing] 예산 초과. pageNo=${pageNo}에서 중단, 내일 이어서 진행.`);
        progress.listingPageNo = pageNo;
        await saveProgress(db, progress);
        return progress;
      }
      throw e;
    }

    if (result.items.length === 0) break;

    const batch = db.batch();
    for (const raw of result.items) {
      const basic = mapEventBasicInfo(raw);
      const docRef = db.collection(config.eventsCollection).doc(basic.contentId);
      batch.set(docRef, { basic, commonSynced: false }, { merge: true });
    }
    await batch.commit();

    console.log(`[listing] pageNo=${pageNo} → ${result.items.length}건 저장 (총 ${result.totalCount}건 중)`);

    if (pageNo * config.pageSize >= result.totalCount) break;
    pageNo++;
  }

  progress.stage = "detailCommon";
  progress.listingPageNo = 1;
  await saveProgress(db, progress);
  console.log("[listing] 전체 완료 → detailCommon 단계로 전환");
  return progress;
}
