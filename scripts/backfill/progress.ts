/**
 * 백필 진행상황을 Firestore _syncMeta/backfillProgress 문서에 기록.
 *
 * Java 비유: Spring Batch의 JobRepository가 StepExecution 상태를 DB에
 * 남겨서 재시작 시 이어할 수 있게 하는 것과 같은 역할.
 * 여기서는 단일 문서 하나로 단순화했습니다 (규모가 작아서 충분함).
 *
 * firebase-admin 최신 버전은 namespace-style(admin.firestore.Firestore)
 * 대신 모듈러 API(import { getFirestore } from "firebase-admin/firestore")를
 * 권장합니다. 타입 네임스페이스 문제를 피하려고 모듈러 방식으로 작성했습니다.
 */
import { initializeApp, cert, App } from "firebase-admin/app";
import { getFirestore, Firestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import * as path from "path";
import { config } from "./config";

let app: App | null = null;

export function initFirebaseAdmin(): Firestore {
  if (!app) {
    app = initializeApp({
      credential: cert(path.resolve(process.cwd(), config.firebaseServiceAccountPath)),
    });
  }
  return getFirestore(app);
}

export type BackfillStage = "basic" | "accessibility" | "festival" | "done";

export interface BackfillProgress {
  stage: BackfillStage;

  // stage === "basic" 진행 상태
  basicContentTypeIndex: number; // config.contentTypeIds 인덱스
  basicPageNo: number;

  // stage === "accessibility" / "festival" 단계는 커서가 필요 없음.
  // tourSpots 문서마다 accessibilitySynced / festivalSynced 플래그를 두고,
  // false인 문서만 쿼리해서 처리 → 처리 즉시 true로 바뀌니 자동으로 대상에서 빠짐.

  updatedAt: Timestamp | null;
}

const DEFAULT_PROGRESS: BackfillProgress = {
  stage: "basic",
  basicContentTypeIndex: 0,
  basicPageNo: 1,
  updatedAt: null,
};

export async function loadProgress(db: Firestore): Promise<BackfillProgress> {
  const snap = await db.doc(config.progressDocPath).get();
  if (!snap.exists) {
    return { ...DEFAULT_PROGRESS };
  }
  return { ...DEFAULT_PROGRESS, ...(snap.data() as Partial<BackfillProgress>) };
}

export async function saveProgress(db: Firestore, progress: BackfillProgress): Promise<void> {
  await db.doc(config.progressDocPath).set(
    {
      ...progress,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
