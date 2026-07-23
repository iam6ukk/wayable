/// contentTypeId별로 "시설정보"에 보여줄 필드 목록 정의.
///
/// TourAPI detailIntro2는 contentTypeId별로 필드명이 전부 다르게 내려오기 때문에
/// (예: 이용시간이 관광지는 usetime, 문화시설은 usetimeculture), 어떤 필드를 어떤
/// 한글 라벨로 보여줄지를 타입별로 명시적으로 정의해둔다. homepage는 모든 타입에서
/// detailCommon2(공통정보) 응답에서 가져온다.
///
/// 축제/공연/행사(contentTypeId=15)는 이 앱이 다루는 데이터셋에 해당 컨텐츠가
/// 존재하지 않아 매핑 대상에서 제외한다.
library;

enum FacilityFieldSource { common, intro }

class FacilityFieldSpec {
  const FacilityFieldSpec(this.source, this.fieldKey, this.label);

  final FacilityFieldSource source;
  final String fieldKey;
  final String label;
}

const kFacilityFieldsByContentType = <String, List<FacilityFieldSpec>>{
  // 관광지
  '12': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'usetime', '이용시간'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'restdate', '쉬는날'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parking', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocenter', '문의처'),
  ],
  // 문화시설
  '14': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'usetimeculture', '이용시간'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'restdateculture', '쉬는날'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'usefee', '이용요금'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parkingculture', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocenterculture', '문의처'),
  ],
  // 레포츠
  '28': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'usetimeleports', '이용시간'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'restdateleports', '쉬는날'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parkingleports', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'reservation', '예약안내'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocenterleports', '문의처'),
  ],
  // 숙박
  '32': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'roomtype', '객실유형'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parkinglodging', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'reservationurl', '예약안내'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocenterlodging', '문의처'),
  ],
  // 쇼핑
  '38': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'opentime', '영업시간'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'restdateshopping', '쉬는날'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parkingshopping', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocentershopping', '문의처'),
  ],
  // 음식점
  '39': [
    FacilityFieldSpec(FacilityFieldSource.common, 'homepage', '홈페이지'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'opentimefood', '영업시간'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'restdatefood', '쉬는날'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'parkingfood', '주차시설'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'reservationfood', '예약안내'),
    FacilityFieldSpec(FacilityFieldSource.intro, 'infocenterfood', '문의처'),
  ],
};
