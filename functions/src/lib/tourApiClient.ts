/**
 * Cloud Functions용 TourAPI 호출 클라이언트.
 *
 * scripts/backfill/tourApiClient.ts와 로직은 거의 동일하지만
 * (일시적 에러 재시도), 배포 대상이 다르기 때문에 별도 파일로 둡니다
 * (scripts/는 Cloud Functions 배포에 포함되지 않음).
 *
 * 델타싱크는 일일 변경분만 다루는 소규모 작업이라 dailyCallBudget
 * 같은 예산 가드는 두지 않았습니다 (필요시 나중에 추가 가능).
 */
import axios from "axios";
import { RawAccessibilityItem, RawFestivalIntroItem, RawTourSyncItem, TourApiResponse } from "../model/rawTourApiTypes";

export class TourApiCallFailedError extends Error {
  constructor(
    message: string,
    public readonly cause: unknown,
  ) {
    super(message);
  }
}

const RETRY_DELAYS_MS = [1000, 3000, 9000];
const BASE_URL = "https://apis.data.go.kr/B551011/KorWithService2";

function isRetryable(error: unknown): boolean {
  if (!axios.isAxiosError(error)) return false;
  if (!error.response) return true; // 타임아웃/네트워크 단절
  const status = error.response.status;
  return status >= 500 && status < 600;
}

function getServiceKey(): string {
  const key = process.env.TOUR_API_SERVICE_KEY;
  if (!key) {
    throw new Error("TOUR_API_SERVICE_KEY 환경변수가 없습니다. functions/.env 파일을 확인하세요.");
  }
  return key;
}

export class TourApiClient {
  private callCount = 0;

  getCallCount(): number {
    return this.callCount;
  }

  private baseParams() {
    return {
      serviceKey: getServiceKey(),
      MobileOS: "ETC",
      MobileApp: "WayAble",
      _type: "json",
    };
  }

  private normalizeItems<T>(body: TourApiResponse<T>["response"]["body"]): T[] {
    const item = body.items?.item;
    if (item === undefined || item === null || (item as unknown) === "") {
      return [];
    }
    return Array.isArray(item) ? item : [item];
  }

  private async getWithRetry<T>(url: string, params: Record<string, unknown>, operationLabel: string): Promise<T> {
    let lastError: unknown;

    for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
      try {
        this.callCount++;
        const { data } = await axios.get<T>(url, { params, timeout: 15000 });
        return data;
      } catch (e) {
        lastError = e;
        if (!isRetryable(e) || attempt === RETRY_DELAYS_MS.length) break;
        const delay = RETRY_DELAYS_MS[attempt];
        console.warn(`[재시도] ${operationLabel} 실패 (시도 ${attempt + 1}/${RETRY_DELAYS_MS.length + 1}), ${delay}ms 후 재시도...`);
        await new Promise((r) => setTimeout(r, delay));
      }
    }

    throw new TourApiCallFailedError(`${operationLabel} 호출이 재시도까지 모두 실패했습니다.`, lastError);
  }

  /** 특정 날짜(YYYYMMDD)에 변경된 전체 콘텐츠 목록. contentTypeId 필터 없이 전부 조회. */
  async fetchChangedByDate(params: {
    modifiedtime: string; // YYYYMMDD
    pageNo: number;
    numOfRows: number;
  }): Promise<{ items: RawTourSyncItem[]; totalCount: number }> {
    const data = await this.getWithRetry<TourApiResponse<RawTourSyncItem>>(
      `${BASE_URL}/areaBasedSyncList2`,
      {
        ...this.baseParams(),
        modifiedtime: params.modifiedtime,
        pageNo: params.pageNo,
        numOfRows: params.numOfRows,
        arrange: "A",
        // showflag는 일부러 지정 안 함 → 표출(1)/비표출(0) 둘 다 받아서
        // 델타싱크에서 표출은 upsert, 비표출은 삭제 처리
      },
      `areaBasedSyncList2(modifiedtime=${params.modifiedtime}, pageNo=${params.pageNo})`,
    );

    this.assertOk(data);
    return {
      items: this.normalizeItems(data.response.body),
      totalCount: data.response.body.totalCount,
    };
  }

  async fetchAccessibility(contentId: string): Promise<RawAccessibilityItem | null> {
    const data = await this.getWithRetry<TourApiResponse<RawAccessibilityItem>>(
      `${BASE_URL}/detailWithTour2`,
      { ...this.baseParams(), contentId, numOfRows: 1, pageNo: 1 },
      `detailWithTour2(contentId=${contentId})`,
    );
    this.assertOk(data);
    return this.normalizeItems(data.response.body)[0] ?? null;
  }

  async fetchFestivalIntro(contentId: string): Promise<RawFestivalIntroItem | null> {
    const data = await this.getWithRetry<TourApiResponse<RawFestivalIntroItem>>(
      `${BASE_URL}/detailIntro2`,
      {
        ...this.baseParams(),
        contentId,
        contentTypeId: "15",
        numOfRows: 1,
        pageNo: 1,
      },
      `detailIntro2(contentId=${contentId})`,
    );
    this.assertOk(data);
    return this.normalizeItems(data.response.body)[0] ?? null;
  }

  private assertOk(data: TourApiResponse<unknown>) {
    const code = data.response.header.resultCode;
    if (code !== "0000") {
      if (code === "03") return; // NODATA_ERROR는 정상 "결과 없음"
      throw new Error(`TourAPI 에러 [${code}] ${data.response.header.resultMsg}`);
    }
  }
}
