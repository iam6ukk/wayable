/**
 * 법정동 지역코드(시/도 + 시군구) 1회성 조회 스크립트.
 *
 * 거의 안 바뀌는 정적 참조 데이터라 앱에서 매번 라이브 호출하는 대신,
 * 여기서 한 번 뽑아 assets/data/area_codes.json으로 번들해서 쓴다.
 * (시/도 1회 + 시/도별 시군구 조회로 총 API 호출 ~17회, 일일 예산에 영향 미미)
 *
 * 실행: npx ts-node scripts/backfill/fetchAreaCodes.ts
 */
import * as fs from "fs";
import * as path from "path";
import { TourApiClient } from "./tourApiClient";

async function main() {
  const client = new TourApiClient();

  const sidoList = await client.fetchLdongCode2();
  console.log(`시/도 ${sidoList.length}개 조회됨`);

  const result = [];
  for (const sido of sidoList) {
    const sigunguList = await client.fetchLdongCode2(sido.code);
    console.log(`  - ${sido.name}(${sido.code}): 시군구 ${sigunguList.length}개`);
    result.push({
      code: sido.code,
      name: sido.name,
      sigungu: sigunguList.map((g) => ({ code: g.code, name: g.name })),
    });
  }

  const outPath = path.resolve(__dirname, "../../assets/data/area_codes.json");
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");

  console.log(`저장 완료: ${outPath}`);
  console.log(`총 API 호출: ${client.getCallCount()}회`);
}

main().catch((e) => {
  console.error("지역코드 조회 실패:", e);
  process.exit(1);
});
