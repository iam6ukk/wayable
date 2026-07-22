/**
 * Cloud Functions용 KorService2 호출 클라이언트 (행사 델타싱크 전용).
 * lib/tourApiClient.ts(KorWithService2)와 별도 — 다른 서비스키/베이스URL.
 */
import axios from "axios";
import { RawDetailCommonItem, RawFestivalListItem } from "../model/rawEventApiTypes";
import { TourApiResponse } from "../model/rawTourApiTypes";

export class TourApiCallFailedError extends Error {
  constructor(
    message: string,
    public readonly cause: unknown,
  ) {
    super(message);
  }
}

const RETRY_DELAYS_MS = [1000, 3000, 9000];
const BASE_URL = "https://apis.data.go.kr/B551011/KorService2";

function isRetryable(error: unknown): boolean {
  if (!axios.isAxiosError(error)) return false;
  if (!error.response) return true;
  const status = error.response.status;
  return status >= 500 && status < 600;
}

function getServiceKey(): string {
  const key = process.env.KORSERVICE_API_SERVICE_KEY;
  if (!key) {
    throw new Error("KORSERVICE_API_SERVICE_KEY 환경변수가 없습니다. functions/.env 파일을 확인하세요.");
  }
  return key;
}

export class EventApiClient {
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

  async searchFestival(params: {
    eventStartDate: string;
    pageNo: number;
    numOfRows: number;
  }): Promise<{ items: RawFestivalListItem[]; totalCount: number }> {
    const data = await this.getWithRetry<TourApiResponse<RawFestivalListItem>>(
      `${BASE_URL}/searchFestival2`,
      {
        ...this.baseParams(),
        eventStartDate: params.eventStartDate,
        pageNo: params.pageNo,
        numOfRows: params.numOfRows,
        arrange: "A",
      },
      `searchFestival2(pageNo=${params.pageNo})`,
    );
    this.assertOk(data);
    return {
      items: this.normalizeItems(data.response.body),
      totalCount: data.response.body.totalCount,
    };
  }

  async fetchDetailCommon(contentId: string): Promise<RawDetailCommonItem | null> {
    const data = await this.getWithRetry<TourApiResponse<RawDetailCommonItem>>(
      `${BASE_URL}/detailCommon2`,
      {
        ...this.baseParams(),
        contentId,
        numOfRows: 1,
        pageNo: 1,
      },
      `detailCommon2(contentId=${contentId})`,
    );
    this.assertOk(data);
    return this.normalizeItems(data.response.body)[0] ?? null;
  }

  private assertOk(data: TourApiResponse<unknown>) {
    const topLevel = data as unknown as {
      resultCode?: string;
      resultMsg?: string;
    };
    if (topLevel?.resultCode && topLevel.resultCode !== "0000") {
      throw new Error(`TourAPI 요청 오류 [${topLevel.resultCode}] ${topLevel.resultMsg}`);
    }

    if (!data || !data.response || !data.response.header) {
      throw new Error("TourAPI 응답 형식 오류 (response.header 없음)");
    }

    const code = data.response.header.resultCode;
    if (code !== "0000") {
      if (code === "03") return;
      throw new Error(`TourAPI 에러 [${code}] ${data.response.header.resultMsg}`);
    }
  }
}
