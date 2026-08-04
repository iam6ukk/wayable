import 'package:flutter_riverpod/legacy.dart';
import '../widgets/bottom_nav_bar.dart';

/// MainShell 위에 push된 화면(예: SpotDetailScreen)에서 하단 탭을 눌렀을 때,
/// 그냥 pop만 하면 이전에 있던 탭으로 돌아갈 뿐 실제로 그 탭으로 전환되지
/// 않는다. 이 프로바이더에 원하는 탭을 담아두면 MainShell이 감지해서 바로
/// 그 탭으로 전환한 뒤 값을 비운다.
final tabSwitchRequestProvider = StateProvider<BottomNavTab?>((ref) => null);
