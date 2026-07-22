/**
 * 일일 행사 델타싱크 (Cloud Functions Scheduled Function)
 *
 * dailyDeltaSync(무장애 콘텐츠, 새벽 5시)와 다른 전략을 씁니다.
 * searchFestival2는 showflag/modifiedtime 기반 증분 동기화를 지원하지 않는
 * "검색" 성격의 오퍼레이션이라, 대신 매일 "현재 진행중+예정 행사" 전체를
 * 다시 받아와서 통째로 새로고침하는 방식으로 갑니다.
 *
 * - eventStartDate 파라미터로 API 단에서부터 범위가 좁혀지기 때문에
 *   (오늘-7일 이후) 전체 물량이 크지 않아 매일 풀리프레시해도 부담 적음
 * - 이번에 응답에 없는 contentId는 "종료되었거나 더 이상 노출되지 않는 행사"로
 *   간주하고 Firestore에서 삭제
 * - 신규이거나 modifiedTime이 바뀐 문서만 detailCommon2로 재조회
 *
 * ⚠️ dailyDeltaSync와 트래픽 예산은 독립적이지만(별도 서비스키), 실행 시각은
 * 30분 뒤로 띄워 로그 확인 시 서로 안 섞이게 했습니다.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { mapEventBasicInfo, mapEventCommonInfo } from "../model/eventTypes";
import { EventApiClient, TourApiCallFailedError } from "../lib/eventApiClient";
import { addDaysToYyyymmdd, toKstYyyymmdd } from "../lib/dateUtils";

const EVENTS_COLLECTION = "events";
const PAGE_SIZE = 100;
/** 오늘 기준 이 값(음수)만큼 이전 날짜부터 포함 - 진행 중인 다일간 행사 누락 방지 */
const EVENT_START_DATE_BUFFER_DAYS = -7;
const MAX_CONSECUTIVE_FAILURES = 8;

export const dailyEventSync = onSchedule(
  {
    schedule: "30 5 * * *",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const client = new EventApiClient();

    const eventStartDate = addDaysToYyyymmdd(toKstYyyymmdd(new Date()), EVENT_START_DATE_BUFFER_DAYS);

    console.log(`[eventSync] eventStartDate=${eventStartDate} 기준 전체 새로고침 시작`);

    // 기존 캐시를 먼저 메모리에 올려서, 항목마다 개별 get() 하지 않고 비교
    const existingSnap = await db.collection(EVENTS_COLLECTION).get();
    const existingByIdMap = new Map(existingSnap.docs.map((d) => [d.id, d.data()]));

    const freshContentIds = new Set<string>();
    let pageNo = 1;

    while (true) {
      const { items, totalCount } = await client.searchFestival({
        eventStartDate,
        pageNo,
        numOfRows: PAGE_SIZE,
      });
      if (items.length === 0) break;

      const batch = db.batch();
      for (const raw of items) {
        freshContentIds.add(raw.contentid);
        const basic = mapEventBasicInfo(raw);
        const existing = existingByIdMap.get(raw.contentid);
        const isNewOrChanged = !existing || existing.basic?.modifiedTime !== basic.modifiedTime;

        const docRef = db.collection(EVENTS_COLLECTION).doc(raw.contentid);
        batch.set(
          docRef,
          {
            basic,
            commonSynced: isNewOrChanged ? false : (existing?.commonSynced ?? false),
          },
          { merge: true },
        );
      }
      await batch.commit();

      console.log(`[eventSync] pageNo=${pageNo} → ${items.length}건 처리 (총 ${totalCount}건 중)`);

      if (pageNo * PAGE_SIZE >= totalCount) break;
      pageNo++;
    }

    // 이번에 못 받아온(종료되었거나 제외된) 행사는 캐시에서 삭제
    const toDelete = [...existingByIdMap.keys()].filter((id) => !freshContentIds.has(id));
    for (const id of toDelete) {
      await db.collection(EVENTS_COLLECTION).doc(id).delete();
    }
    if (toDelete.length > 0) {
      console.log(`[eventSync] 종료/제외된 행사 ${toDelete.length}건 삭제`);
    }

    // 신규/변경분만 detailCommon2로 상세(홈페이지 등) 보강
    const needsCommonSnap = await db.collection(EVENTS_COLLECTION).where("commonSynced", "==", false).get();

    let consecutiveFailures = 0;
    for (const doc of needsCommonSnap.docs) {
      try {
        const raw = await client.fetchDetailCommon(doc.id);
        consecutiveFailures = 0;
        if (raw) {
          await doc.ref.set({ common: mapEventCommonInfo(raw), commonSynced: true }, { merge: true });
        } else {
          await doc.ref.set({ commonSynced: true }, { merge: true });
        }
      } catch (e) {
        consecutiveFailures++;
        console.warn(`[eventSync] contentId=${doc.id} detailCommon2 갱신 실패: ${e instanceof TourApiCallFailedError ? e.message : e}`);
        if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
          console.error("[eventSync] 연속 실패 다발 — 오늘은 여기서 중단합니다.");
          break;
        }
      }
    }

    console.log(`[eventSync] 완료. 총 호출 ${client.getCallCount()}회`);
  },
);
