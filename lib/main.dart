import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:wayable/screen/auth/landing.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'navigation/navigator_key.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerFontLicenses();
  _registerImageLicenses();

  await dotenv.load(fileName: ".env");
  final kakaoNativeAppKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  // 지도 SDK 인증
  // 로그인용 KakaoSdk.init과는 별개 패키지(kakao_map_sdk)
  if (kakaoNativeAppKey != null) {
    await KakaoMapSdk.instance.initialize(kakaoNativeAppKey);
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: MyApp()));
}

// showLicensePage는 pub 패키지 라이선스만 자동 수집하므로,
// assets/fonts에 직접 번들한 Pretendard/CalSans 라이선스는 수동으로 등록
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final pretendard = await rootBundle.loadString(
      'assets/licenses/pretendard_OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Pretendard'], pretendard);

    final calSans = await rootBundle.loadString(
      'assets/licenses/cal_sans_OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['CalSans'], calSans);
  });
}

// Freepik(Magnific)의 "출처표기 조건부 무료 상업이용" 라이선스 아이콘 —
// 홈 화면 상황별 카드(situation_*)에 쓰는 3D 아이콘 5종의 출처 고지
void _registerImageLicenses() {
  const attribution =
      'designed by Freepik - Magnific.com (https://www.magnific.com)';
  const items = {
    '고령자 맞춤 아이콘 (situation_seniorCompanion)':
        'https://www.magnific.com/free-psd/3d-render-disability-icon_165590100.htm',
    '시각장애 맞춤 아이콘 (situation_visionAssist)':
        'https://www.magnific.com/kr/free-psd/visual-impairment-stick-icon-rendering_90428382.htm',
    '영유아가족 맞춤 아이콘 (situation_infantFamily)':
        'https://www.magnific.com/free-psd/3d-illustration-with-rules-orderly-conduct_171608169.htm',
    '지체장애 맞춤 아이콘 (situation_physicalAssist)':
        'https://www.magnific.com/free-psd/3d-illustration-reduced-mobility-with-wheelchair_40336583.htm',
    '청각장애 맞춤 아이콘 (situation_hearingAssist)':
        'https://www.magnific.com/free-psd/3d-render-disability-icon_165590283.htm',
  };

  LicenseRegistry.addLicense(() async* {
    for (final entry in items.entries) {
      yield LicenseEntryWithLineBreaks(
        ['Freepik 3D 아이콘 - ${entry.key}'],
        '''
License type: Free for commercial use WITH ATTRIBUTION license
Licensor: Freepik - Magnific.com
Item URL: ${entry.value}

Attribution: $attribution
''',
      );
    }
  });
}

// Android 기본 오버스크롤(당길 때 화면이 늘어나는 stretch) 효과 제거
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 뷰포트 360*800 적용 (갤럭시 표준 뷰포트)
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        debugShowCheckedModeBanner: false,
        scrollBehavior: _NoStretchScrollBehavior(),
        theme: ThemeData(
          fontFamily: 'Pretendard', // 한글 폰트 프리텐다드로 전역 지정
          useMaterial3: true,
        ),
        // 사용자 설정에 따라 레이아웃이 넘쳐 깨질 수 있기 때문에 최대 1.15배 범위까지만 조정
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.15,
          child: child!,
        ),
        home: const LandingPage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
