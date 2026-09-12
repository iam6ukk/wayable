<img src="assets/images/common/wayable.png" width="120" alt="WayAble logo" />

### Wayable 웨이어블
웨이어블(Wayable)은 장애인, 고령자, 영유아 동반 가족 등 이동과 접근성 정보를 필요로 하는 사용자가 자신의 조건에 맞는 여행지를 탐색하고, 방문 전에 필요한 편의 정보를 확인할 수 있도록 돕는 **여행지 탐색 서비스** 입니다.

여행지별 **기본 관광 정보와 접근성·편의 정보**를 제공하며, 사용자가 설정한 접근성 조건과 여행지가 제공하는 편의 정보를 비교해 **적합 레벨**을 산정합니다. 이를 통해 여러 여행지의 접근성 정보를 사용자가 일일이 비교하지 않아도 자신에게 필요한 조건을 어느 정도 충족하는지 직관적으로 확인할 수 있도록 지원합니다.

👉 [Google Play Store 바로가기](https://play.google.com/store/apps/details?id=com.wayable.app)


<br>

### 👥 팀 소개
| 이름   | 역할       | GitHub                     |
| ------ | ---------- | -------------------------- |
| 김유경 | 팀장, 기획 및 풀스택 개발 | https://github.com/iam6ukk |
| 장서온 | 기획 및 풀스택 개발       | https://github.com/jxxny   |
| 정가연 | 기획 및디자인     | https://github.com/yonggaa |
| 정민경 | 기획 및 디자인     | https://github.com/5mkown  |


<br>


### ⚙️ 개발 환경 
- Flutter SDK `^3.12.2` (Dart)
- Node.js 24 (Cloud Functions 빌드·배포용)


<br>


### 🛠️ 기술 스택
**Frontend**

* Flutter
* Riverpod (flutter_riverpod)
* kakao_map_sdk (지도)
* geolocator (위치)

**Backend**
* Cloud Functions for Firebase (TypeScript)
* Cloud Firestore

**Authentication**
* Firebase Authentication
* 카카오 로그인 (kakao_flutter_sdk_user)
* 구글 로그인 (google_sign_in)

**External API**
* 한국관광공사 무장애 여행정보 Open API (KorWithService2)


<br>


### 🪄 주요 기능
- **홈** — 월별 추천 여행지 배너, 현재 위치 기반 추천 여행지("오늘의 발견"), 접근성 유형별 바로가기, 인기 저장 여행지 등 주요 기능 바로가기
- **맞춤 여행지 탐색** — 접근성 유형과 지역, 시설 유형(관광지/문화시설/레포츠/숙박/쇼핑/음식점)에 접근성 조건을 조합해 여행지 검색, 여행지명·주소·편의 정보 확인
- **지도 기반 탐색** — 카카오맵 기반으로 현재 위치 주변 또는 원하는 지역으로 이동해 여행지 검색, 여행지명·주소·적합 레벨·주요 편의 정보 확인
- **여행지 저장 목록** — 마음에 드는 여행지를 폴더별로 정리해 저장/관리 (로그인 회원 전용)
- **마이페이지** — 카카오/구글 로그인, **접근성 프로필 설정**(지체·시각·청각장애 보조, 영유아 가족, 고령자 동반 등 유형별 세부 편의 정보 및 관심 지역 설정)


<br>


### 🧩 실행 방법
```bash
# 1. 패키지 설치
flutter pub get

# 2. 프로젝트 루트에 .env 파일 생성 후 아래 항목 채우기
KAKAO_NATIVE_APP_KEY=
KAKAO_REST_API_KEY=
GOOGLE_CLIENT_ID=
TOUR_API_SERVICE_KEY=

# 3. Firebase 설정 파일 배치
#    android/app/google-services.json

# 4. 앱 실행
flutter run
```

Cloud Functions를 로컬에서 실행하려면:

```bash
cd functions
npm install
npm run build
firebase emulators:start --only functions
```
