/**
 * TourAPI 호출 래퍼.
 *
 * Java 비유: RestTemplate에 인터셉터로 rate limit + call count 체크 +
 * @Retryable 재시도 로직을 끼워둔 것과 같은 역할.
 *
 * 504 Gateway Timeout처럼 TourAPI 서버 쪽의 "일시적" 문제는 재시도하면
 * 대부분 해결됩니다. 반면 서비스키 오류, 파라미터 오류 같은 건 재시도해도
 * 똑같이 실패하니 재시도 대상에서 제외합니다.
 */
import axios, { AxiosError } from "axios";
import { config } from "./config";
import { RawAccessibilityItem, RawFestivalIntroItem, RawTourSyncItem, TourApiResponse } from "../../functions/src/model/rawTourApiTypes";

/** 오늘 호출 예산을 다 썼을 때 던지는 시그널 에러. run.ts에서 잡아서 정상 종료 처리. */
export class DailyBudgetExceededError extends Error {
  constructor() {
    super("오늘 호출 예산을 모두 사용했습니다. 내일 다시 실행해주세요.");
  }
}

/** 재시도까지 다 실패한 경우 던지는 에러. 호출부에서 "이 건만 스킵"하는 용도로 씀. */
export class TourApiCallFailedError extends Error {
  constructor(
    message: string,
    public readonly cause: unknown,
  ) {
    super(message);
  }
}

/** 재시도 사이 대기 시간(ms). 순서대로 시도. */
const RETRY_DELAYS_MS = [1000, 3000, 9000];

function isRetryable(error: unknown): boolean {
  if (!axios.isAxiosError(error)) return false;
  const axiosErr = error as AxiosError;

  // 응답 자체를 못 받음 (타임아웃, DNS 실패, 연결 끊김 등) → 재시도 대상
  if (!axiosErr.response) return true;

  // 5xx (504 Gateway Timeout 포함) → 서버 쪽 일시적 문제로 간주, 재시도 대상
  const status = axiosErr.response.status;
  if (status >= 500 && status < 600) return true;

  return false;
}

export class TourApiClient {
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
      serviceKey: config.tourApiServiceKey,
      MobileOS: config.mobileOs,
      MobileApp: config.mobileApp,
      _type: "json",
    };
  }

  /** 응답 items.item이 0건/1건/N건일 때 형태가 다른 걸 배열로 통일 */
  private normalizeItems<T>(body: TourApiResponse<T>["response"]["body"]): T[] {
    const item = body.items?.item;
    if (item === undefined || item === null || (item as unknown) === "") {
      return [];
    }
    return Array.isArray(item) ? item : [item];
  }

  /**
   * axios.get을 감싸서 일시적 에러(504, 타임아웃, 네트워크 단절)를 자동 재시도.
   * 최대 재시도까지 다 실패하면 TourApiCallFailedError로 감싸서 던짐
   * (호출부가 "이 건만 스킵"할지 판단할 수 있게).
   */
  private async getWithRetry<T>(url: string, params: Record<string, unknown>, operationLabel: string): Promise<T> {
    let lastError: unknown;

    for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
      try {
        const { data } = await axios.get<T>(url, {
          params,
          timeout: 15000, // 15초 넘게 응답 없으면 타임아웃으로 간주하고 재시도
        });
        return data;
      } catch (e) {
        lastError = e;
        if (!isRetryable(e) || attempt === RETRY_DELAYS_MS.length) {
          break;
        }
        const delay = RETRY_DELAYS_MS[attempt];
        console.warn(`[재시도] ${operationLabel} 실패 (시도 ${attempt + 1}/${RETRY_DELAYS_MS.length + 1}), ${delay}ms 후 재시도...`);
        await new Promise((r) => setTimeout(r, delay));
      }
    }

    throw new TourApiCallFailedError(`${operationLabel} 호출이 재시도까지 모두 실패했습니다.`, lastError);
  }

  async fetchAreaBasedSyncList(params: {
    contentTypeId: string;
    pageNo: number;
    numOfRows: number;
    showflag?: "0" | "1";
    modifiedtime?: string; // YYYYMMDD 등
  }): Promise<{ items: RawTourSyncItem[]; totalCount: number }> {
    await this.guardAndDelay();
    this.callCount++;

    const data = await this.getWithRetry<TourApiResponse<RawTourSyncItem>>(
      `${config.baseUrl}/areaBasedSyncList2`,
      {
        ...this.baseParams(),
        contentTypeId: params.contentTypeId,
        pageNo: params.pageNo,
        numOfRows: params.numOfRows,
        showflag: params.showflag,
        modifiedtime: params.modifiedtime,
        arrange: "A", // 제목순 - 페이지 간 순서 안정성 확보
      },
      `areaBasedSyncList2(contentTypeId=${params.contentTypeId}, pageNo=${params.pageNo})`,
    );

    this.assertOk(data);
    return {
      items: this.normalizeItems(data.response.body),
      totalCount: data.response.body.totalCount,
    };
  }

  async fetchAccessibility(contentId: string): Promise<RawAccessibilityItem | null> {
    await this.guardAndDelay();
    this.callCount++;

    const data = await this.getWithRetry<TourApiResponse<RawAccessibilityItem>>(
      `${config.baseUrl}/detailWithTour2`,
      {
        ...this.baseParams(),
        contentId,
        numOfRows: 1,
        pageNo: 1,
      },
      `detailWithTour2(contentId=${contentId})`,
    );

    this.assertOk(data);
    const items = this.normalizeItems(data.response.body);
    return items[0] ?? null;
  }

  async fetchFestivalIntro(contentId: string): Promise<RawFestivalIntroItem | null> {
    await this.guardAndDelay();
    this.callCount++;

    const data = await this.getWithRetry<TourApiResponse<RawFestivalIntroItem>>(
      `${config.baseUrl}/detailIntro2`,
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
    const items = this.normalizeItems(data.response.body);
    return items[0] ?? null;
  }

  /**
   * ldongCode2 (법정동 코드 조회). lDongRegnCd를 안 넘기면 시/도 목록, 넘기면 그 시/도의
   * 시군구 목록. areaCode2(구 지역코드)는 2025년 12월까지만 활용 가능해서 대신 이걸 쓴다.
   * 정적 참조 데이터라 일회성으로만 호출하고 결과를 앱에 번들해서 쓴다 (fetchAreaCodes.ts 참고).
   */
  async fetchLdongCode2(lDongRegnCd?: string): Promise<{ code: string; name: string }[]> {
    await this.guardAndDelay();
    this.callCount++;

    const data = await this.getWithRetry<TourApiResponse<{ code: string; name: string }>>(
      `${config.baseUrl}/ldongCode2`,
      {
        ...this.baseParams(),
        numOfRows: 100,
        pageNo: 1,
        ...(lDongRegnCd ? { lDongRegnCd } : {}),
      },
      `ldongCode2(lDongRegnCd=${lDongRegnCd ?? "전체"})`,
    );

    this.assertOk(data);
    return this.normalizeItems(data.response.body);
  }

  private assertOk(data: TourApiResponse<unknown>) {
    const code = data.response.header.resultCode;
    if (code !== "0000") {
      // 03(NODATA_ERROR)은 정상적인 "결과 없음"이라 에러로 안 던짐
      if (code === "03") return;
      throw new Error(`TourAPI 에러 [${code}] ${data.response.header.resultMsg}`);
    }
  }
}
