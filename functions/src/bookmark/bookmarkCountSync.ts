/**
 * 북마크 랭킹(top5)용 tourSpots.bookmarkCount 동기화.
 *
 * users/{uid}/bookmarks/{folderId}/spots/{spotId} 문서의 생성/삭제에 반응해서
 * tourSpots/{contentId}.bookmarkCount를 증감시킨다. 문서 id가 곧 contentId로
 * 고정되어 있어(BookmarkService.saveSpotToFolder), 다른 폴더로 옮기는 동작은
 * 기존 폴더 문서 삭제 + 새 폴더 문서 생성이라 -1과 +1이 자동으로 상쇄된다
 * (폴더 구분 없이 "현재 어딘가에 저장돼 있는가" 하나만 세는 셈).
 *
 * tourSpots 문서가 이미 없으면(델타싱크가 비표출 처리로 삭제한 경우) 건드리지
 * 않는다 — bookmarkCount 필드만 있는 반쪽 문서가 되살아나는 걸 막기 위함.
 */
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";

const TOUR_SPOTS_COLLECTION = "tourSpots";
const BOOKMARK_SPOT_DOCUMENT = "users/{uid}/bookmarks/{folderId}/spots/{spotId}";

export const onBookmarkSpotCreated = onDocumentCreated(
  { document: BOOKMARK_SPOT_DOCUMENT, region: "asia-northeast3" },
  async (event) => {
    await adjustBookmarkCount(event.params.spotId, 1);
  },
);

export const onBookmarkSpotDeleted = onDocumentDeleted(
  { document: BOOKMARK_SPOT_DOCUMENT, region: "asia-northeast3" },
  async (event) => {
    await adjustBookmarkCount(event.params.spotId, -1);
  },
);

async function adjustBookmarkCount(contentId: string, delta: 1 | -1): Promise<void> {
  const db = getFirestore();
  const ref = db.collection(TOUR_SPOTS_COLLECTION).doc(contentId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;

    const current = (snap.data()?.bookmarkCount as number | undefined) ?? 0;
    // 델타싱크 연쇄삭제와 겹치는 등 순서가 꼬여도 음수로 내려가지 않도록 방어.
    const next = Math.max(0, current + delta);
    tx.update(ref, { bookmarkCount: next });
  });
}
