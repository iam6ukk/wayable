import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FirestoreTourSpotDoc } from "../model";

/**
 * 앱 탐색 화면(explore_screen.dart)의 검색 요청 파라미터.
 *
 * keyword(제목 부분일치)/acceptableFields(접근성 상세필드 OR)는 Firestore
 * 쿼리로 표현할 수 없어서, 지역/카테고리만 Firestore where로 먼저 좁히고
 * 나머지는 이 함수 안에서 직접 필터링한다. 클라이언트가 통째로 받아서
 * 걸러야 했던 예전 방식과 달리, 여기서 이미 걸러진 페이지 하나만 돌려준다.
 */
interface SearchSpotsRequest {
  keyword?: string;
  regionCode?: string;
  categoryIds?: string[];
  /** AccessibilityField.name 값 목록. 비어있으면 접근성 조건 없음. */
  acceptableFields?: string[];
  /** 선택한 시/군구(구 단위 OR 목록, SigunguCode.memberCodes). */
  sigunguMemberCodes?: string[];
  page?: number;
  pageSize?: number;
}

const ACCESSIBILITY_GROUPS = [
  "physical",
  "visual",
  "hearing",
  "infantFamily",
] as const;

function isPopulated(value: unknown): boolean {
  return value !== null && value !== undefined && value !== "";
}

/** explore_screen.dart의 _matchesFilters와 동일한 OR 매칭 규칙. */
function matchesAcceptableFields(
  doc: FirestoreTourSpotDoc,
  acceptableFields: string[]
): boolean {
  if (acceptableFields.length === 0) return true;
  const accessibility = doc.accessibility;
  if (!accessibility) return false;

  for (const group of ACCESSIBILITY_GROUPS) {
    const groupData = accessibility[group] as unknown as
      | Record<string, unknown>
      | undefined;
    if (!groupData) continue;
    for (const field of acceptableFields) {
      if (isPopulated(groupData[field])) return true;
    }
  }
  return false;
}

export const searchTourSpots = onCall(
  // regionCode 없이(=전국 대상) 호출되면 tourSpots 컬렉션 전체를 한 번에
  // 메모리에 올리는데, 데이터가 늘면서 기본 256MiB를 넘겨 컨테이너가 강제
  // 종료되는 사고가 실제로 나고 있었다(로그: "Memory limit of 256 MiB
  // exceeded" → 요청 자체가 응답 없이 끊김 → 클라이언트는 이걸 실패로 보고
  // 빈 결과로 처리 → 화면엔 "검색결과 없음"으로만 보임). 512MiB로 올려
  // 당장의 크래시부터 막는다 — 근본적으로는 전체 스캔 대신 Firestore
  // 쿼리로 좁히는 구조 개선이 필요하다.
  { region: "asia-northeast3", memory: "512MiB" },
  async (request) => {
    const data = (request.data ?? {}) as SearchSpotsRequest;
    const page = data.page && data.page > 0 ? data.page : 1;
    const pageSize = data.pageSize && data.pageSize > 0 ? data.pageSize : 6;
    const keyword = (data.keyword ?? "").trim().toLowerCase();
    const acceptableFields = data.acceptableFields ?? [];
    const sigunguMemberCodes = data.sigunguMemberCodes ?? [];

    try {
      let query: FirebaseFirestore.Query = admin
        .firestore()
        .collection("tourSpots");
      if (data.regionCode) {
        query = query.where("basic.lDongRegnCd", "==", data.regionCode);
      }
      if (data.categoryIds && data.categoryIds.length > 0) {
        query = query.where("basic.contentTypeId", "in", data.categoryIds);
      }

      const snapshot = await query.get();

      const matched: { id: string; doc: FirestoreTourSpotDoc }[] = [];
      for (const docSnapshot of snapshot.docs) {
        const doc = docSnapshot.data() as FirestoreTourSpotDoc;

        if (keyword) {
          const titleMatches = doc.basic.title.toLowerCase().includes(keyword);
          const address = `${doc.basic.addr1} ${doc.basic.addr2 ?? ""}`.toLowerCase();
          const addressMatches = address.includes(keyword);
          if (!titleMatches && !addressMatches) continue;
        }
        if (
          sigunguMemberCodes.length > 0 &&
          !sigunguMemberCodes.includes(doc.basic.lDongSignguCd ?? "")
        ) {
          continue;
        }
        if (!matchesAcceptableFields(doc, acceptableFields)) continue;

        matched.push({ id: docSnapshot.id, doc });
      }

      const totalCount = matched.length;
      const start = (page - 1) * pageSize;
      const pageItems = matched.slice(start, start + pageSize);

      return {
        items: pageItems.map(({ id, doc }) => ({ id, ...doc })),
        totalCount,
      };
    } catch (error) {
      console.error("[searchTourSpots] 조회 실패", error);
      throw new HttpsError("internal", "여행지 검색에 실패했습니다.");
    }
  }
);
