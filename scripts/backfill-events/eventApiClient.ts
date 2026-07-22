/**
 * KorService2(일반 관광정보 서비스) 호출 클라이언트 - 행사 백필 전용.
 *
 * scripts/backfill/tourApiClient.ts(KorWithService2용)와 구조는 동일하되,
 * 호출 대상 오퍼레이션과 베이스URL/서비스키가 다릅니다.
 */
import axios from "axios";
import { config } from "./config";
import { TourApiResponse } from "../../functions/src/model/rawTourApiTypes";
import { RawDetailCommonItem, RawFestivalListItem } from "../../functions/src/model/rawEventApiTypes";

export class DailyBudgetExceededError extends Error {
  constructor() {
    super("오늘 호출 예산을 모두 사용했습니다. 내일 다시 실행해주세요.");
  }
}

export class TourApiCallFailedError extends Error {
  constructor(
    message: string,
    public readonly cause: unknown,
  ) {
    super(message);
  }
}

const RETRY_DELAYS_MS = [1000, 3000, 9000];

function isRetryable(error: unknown): boolean {
  if (!axios.isAxiosError(error)) return false;
  if (!error.response) return true;
  const status = error.response.status;
  return status >= 500 && status < 600;
}

export class EventApiClient {
  private callCount = 0;

  getCallCount(): number {
    return this.callCount;
  }

  private async guardAndDelay(): Promise<void> {
    if (this.callCount >= config.dailyCallBudget) {
      throw new DailyBudgetExceededError();
    }
    if (this.callCount > 0) {
      await new Promise((r) => setTimeout(r, config.callDelayMs));
    }
  }

  private baseParams() {
    return {
      serviceKey: config.serviceKey,
      MobileOS: config.mobileOs,
      MobileApp: config.mobileApp,
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
    eventStartDate: string; // YYYYMMDD, 필수 파라미터
    pageNo: number;
    numOfRows: number;
  }): Promise<{ items: RawFestivalListItem[]; totalCount: number }> {
    await this.guardAndDelay();

    const data = await this.getWithRetry<TourApiResponse<RawFestivalListItem>>(
      `${config.baseUrl}/searchFestival2`,
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
    await this.guardAndDelay();

    const data = await this.getWithRetry<TourApiResponse<RawDetailCommonItem>>(
      `${config.baseUrl}/detailCommon2`,
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
    // 파라미터 오류 등은 response.header 없이 최상위에 resultCode/resultMsg로 옴
    const topLevel = data as unknown as {
      resultCode?: string;
      resultMsg?: string;
    };
    if (topLevel?.resultCode && topLevel.resultCode !== "0000") {
      throw new Error(`TourAPI 요청 오류 [${topLevel.resultCode}] ${topLevel.resultMsg}`);
    }

    if (!data || !data.response || !data.response.header) {
      console.error("[진단] TourAPI 응답이 예상 형식이 아닙니다. 실제 응답:", JSON.stringify(data, null, 2).slice(0, 2000));
      throw new Error("TourAPI 응답 형식 오류 (response.header 없음)");
    }

    const code = data.response.header.resultCode;
    if (code !== "0000") {
      if (code === "03") return; // NODATA_ERROR는 정상 "결과 없음"
      throw new Error(`TourAPI 에러 [${code}] ${data.response.header.resultMsg}`);
    }
  }
}
