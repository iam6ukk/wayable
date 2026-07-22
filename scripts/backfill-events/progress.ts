/**
 * 행사 백필 진행상황을 Firestore _syncMeta/eventsBackfillProgress에 기록.
 * 기존 scripts/backfill/progress.ts와 동일한 패턴, 별도 프로세스라 앱 인스턴스는 독립적으로 생성.
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

export type BackfillStage = "listing" | "detailCommon" | "done";

export interface BackfillProgress {
  stage: BackfillStage;
  listingPageNo: number;
  updatedAt: Timestamp | null;
}

const DEFAULT_PROGRESS: BackfillProgress = {
  stage: "listing",
  listingPageNo: 1,
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
  await db.doc(config.progressDocPath).set({ ...progress, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}
