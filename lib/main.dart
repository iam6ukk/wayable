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
