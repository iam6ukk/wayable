import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";

admin.initializeApp();

// 클라이언트(한국)와 카카오 API(kapi.kakao.com, 한국) 모두 한국에 있는데
// region 미지정 시 기본값인 us-central1에 배포되어 로그인마다 태평양을
// 여러 번 왕복하는 지연이 생겼다. 서울 리전으로 고정해 그 지연을 없앤다.
export const kakaoCustomToken = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    const kakaoAccessToken = request.data.kakaoAccessToken;

    if (!kakaoAccessToken) {
      throw new HttpsError("invalid-argument", "카카오 토큰이 없습니다.");
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
      throw new HttpsError("internal", "카카오 인증 실패");
    }
  }
);

export { dailyDeltaSync } from "./batch/dailyDeltaSync";
export { dailyEventSync } from "./batch/dailyEventSync";
