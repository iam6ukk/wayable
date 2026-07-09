import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

admin.initializeApp();

export const kakaoCustomToken = functions.https.onCall(async (request) => {
  const kakaoAccessToken = request.data.kakaoAccessToken;

  if (!kakaoAccessToken) {
    throw new functions.https.HttpsError("invalid-argument", "카카오 토큰이 없습니다.");
  }

  try {
    // 1. 카카오 서버에 토큰 검증 요청
    const kakaoResponse = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: {
        Authorization: `Bearer ${kakaoAccessToken}`,
      },
    });

    // 카카오 고유 ID 추출 -> UID 생성
    const kakaoUserId = kakaoResponse.data.id.toString();
    const uid = `kakao:${kakaoUserId}`;

    // 2. Firebase Custom Token 생성
    const firebaseToken = await admin.auth().createCustomToken(uid);

    return { firebaseToken };
  } catch (error) {
    console.error(error);
    throw new functions.https.HttpsError("internal", "카카오 인증 실패");
  }
});

export { dailyDeltaSync } from "./batch/dailyDeltaSync";
