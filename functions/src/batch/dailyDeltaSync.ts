/**
 * 일일 델타싱크 (Cloud Functions Scheduled Function)
 *
 * 매일 새벽 5시(KST)에 실행되어, "마지막으로 성공한 날짜" 다음날부터
 * 어제까지의 변경분을 areaBasedSyncList2(modifiedtime 필터)로 가져와
 * tourSpots 컬렉션에 반영합니다.
 *
 * "어제까지"만 처리하는 이유: 오늘 데이터는 TourAPI 쪽에서 아직 갱신이
 * 다 안 끝났을 수 있어서, 하루 지난 뒤(=완전히 확정된 뒤) 반영하는 게 안전합니다.
 *
 * 진행상황을 Firestore에 저장해두기 때문에, 하루 실행이 통째로 실패해도
 * 다음날 자동으로 밀린 날짜까지 따라잡습니다 (백필과 동일한 체크포인트 철학).
 *
 * ⚠️ 배포 타이밍 주의: 백필(scripts/backfill)이 끝나기 전에 이 함수를
 * 배포/활성화하면, 같은 서비스키의 일일 트래픽 한도(1,000건)를 백필과
 * 나눠 써야 해서 충돌납니다. 백필이 stage=done 될 때까지 배포를 미루세요.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { mapAccessibilityInfo, mapBasicInfo, mapFestivalIntroInfo } from "../model";
import { RawTourSyncItem } from "../model/rawTourApiTypes";
import { TourApiCallFailedError, TourApiClient } from "../lib/tourApiClient";
import { addDaysToYyyymmdd, isBefore, toKstYyyymmdd } from "../lib/dateUtils";

const TOUR_SPOTS_COLLECTION = "tourSpots";
const PROGRESS_DOC_PATH = "_syncMeta/deltaSyncProgress";
const PAGE_SIZE = 100;

/**
 * 백필 basic 단계가 실제로 완료된 날짜 - 1일.
 * 첫 델타싱크 실행 시(progress 문서가 아직 없을 때) 이 날짜 다음날부터
 * 캐치업을 시작합니다. 백필 basic 단계를 실행한 실제 날짜로 맞춰두세요.
 */
const INITIAL_CATCHUP_BASE_DATE = "20260705";

export const dailyDeltaSync = onSchedule(
  {
    schedule: "0 5 * * *",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const client = new TourApiClient();

    const progressRef = db.doc(PROGRESS_DOC_PATH);
    const progressSnap = await progressRef.get();
    let lastSyncedDate: string = progressSnap.exists ? (progressSnap.data()!.lastSyncedDate as string) : INITIAL_CATCHUP_BASE_DATE;

    const todayKst = toKstYyyymmdd(new Date());
    const yesterdayKst = addDaysToYyyymmdd(todayKst, -1);

    let currentDate = addDaysToYyyymmdd(lastSyncedDate, 1);

    if (isBefore(yesterdayKst, currentDate)) {
      console.log(`[deltaSync] 처리할 날짜 없음 (마지막 동기화: ${lastSyncedDate}). 종료.`);
      return;
    }

    console.log(`[deltaSync] ${currentDate} ~ ${yesterdayKst} 구간 동기화 시작`);

    while (!isBefore(yesterdayKst, currentDate)) {
      await syncOneDay(db, client, currentDate);

      lastSyncedDate = currentDate;
      await progressRef.set({ lastSyncedDate, updatedAt: FieldValue.serverTimestamp() }, { merge: true });

      currentDate = addDaysToYyyymmdd(currentDate, 1);
    }

    console.log(`[deltaSync] 완료. 총 호출 ${client.getCallCount()}회, 마지막 동기화 날짜: ${lastSyncedDate}`);
  },
);

async function syncOneDay(db: FirebaseFirestore.Firestore, client: TourApiClient, dateStr: string): Promise<void> {
  let pageNo = 1;

  while (true) {
    const { items, totalCount } = await client.fetchChangedByDate({
      modifiedtime: dateStr,
      pageNo,
      numOfRows: PAGE_SIZE,
    });

    if (items.length === 0) break;

    for (const raw of items) {
      await syncOneItem(db, client, raw);
    }

    console.log(`[deltaSync] ${dateStr} pageNo=${pageNo} → ${items.length}건 처리 (총 ${totalCount}건 중)`);

    if (pageNo * PAGE_SIZE >= totalCount) break;
    pageNo++;
  }
}

async function syncOneItem(db: FirebaseFirestore.Firestore, client: TourApiClient, raw: RawTourSyncItem): Promise<void> {
  const docRef = db.collection(TOUR_SPOTS_COLLECTION).doc(raw.contentid);

  if (raw.showflag === "0") {
    await docRef.delete();
    console.log(`[deltaSync] contentId=${raw.contentid} 비표출 처리(showflag=0) → 삭제`);
    return;
  }

  const basic = mapBasicInfo(raw);
  await docRef.set({ basic }, { merge: true });

  // 접근성 정보 갱신 (변경된 콘텐츠라 캐시된 접근성도 최신화 필요)
  try {
    const accessRaw = await client.fetchAccessibility(basic.contentId);
    if (accessRaw) {
      await docRef.set({ accessibility: mapAccessibilityInfo(accessRaw), accessibilitySynced: true }, { merge: true });
    } else {
      await docRef.set({ accessibilitySynced: true }, { merge: true });
    }
  } catch (e) {
    // 재시도까지 실패하면 일단 false로 남겨두고 다음 기회에 수동/별도 배치로 보정
    // (델타싱크는 "오늘 변경된 것"만 보므로, 오늘 이후 이 콘텐츠가 다시 변경되지
    // 않으면 자동 재시도 기회가 없습니다 — 실패 로그를 주기적으로 확인해주세요)
    console.warn(`[deltaSync] contentId=${basic.contentId} 접근성 정보 갱신 실패: ${e instanceof TourApiCallFailedError ? e.message : e}`);
    await docRef.set({ accessibilitySynced: false }, { merge: true });
  }

  // 축제 소개정보 갱신 (contentTypeId=15만 해당)
  if (basic.contentTypeId === "15") {
    try {
      const festivalRaw = await client.fetchFestivalIntro(basic.contentId);
      if (festivalRaw) {
        await docRef.set({ festival: mapFestivalIntroInfo(festivalRaw), festivalSynced: true }, { merge: true });
      } else {
        await docRef.set({ festivalSynced: true }, { merge: true });
      }
    } catch (e) {
      console.warn(`[deltaSync] contentId=${basic.contentId} 축제 정보 갱신 실패: ${e instanceof TourApiCallFailedError ? e.message : e}`);
      await docRef.set({ festivalSynced: false }, { merge: true });
    }
  } else {
    await docRef.set({ festivalSynced: true }, { merge: true });
  }
}
