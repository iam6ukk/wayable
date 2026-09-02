import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:wayable/widgets/app_dialog.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../model/region/area_code.dart';
import '../../providers/auth_provider.dart';
import '../../services/region/area_code_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/toast.dart';
import '../auth/login_screen.dart';
import 'accessibility_screen.dart';
import 'faq_screen.dart';

const _inquiryFormUrl = 'https://forms.gle/gLR5yczAz5C7BHvp6';
const _privacyPolicyUrl =
    'https://tattered-kookaburra-e94.notion.site/Wayable-3b49b554d701800189f1faf79b9d16ed';
const _termsOfServiceUrl =
    'https://tattered-kookaburra-e94.notion.site/Wayable-3b49b554d70180cd99d0ec6cfb850997';

AccessibilityProfile? _profileFromName(String name) {
  for (final profile in AccessibilityProfile.values) {
    if (profile.name == name) return profile;
  }
  return null;
}

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  void _openOpenSourceLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'Wayable');
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      showAndroidToast(context, '페이지를 열 수 없습니다.');
    }
  }

  void _openFaq(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FaqScreen()));
  }

  // 접근성 프로필 설정 화면으로 이동하는 함수
  void _openAccessibilitySetting(BuildContext context) {
    final myPageRoute = ModalRoute.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccessibilityScreen(
          onComplete: () {
            Navigator.of(context).popUntil((route) => route == myPageRoute);
          },
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // 로그아웃 확인 다이얼로그
    final confirmed = await showTwoButtonDialog(
      context,
      content: '로그아웃하시겠습니까?',
      primaryLabel: '확인',
      secondaryLabel: '취소',
    );
    if (confirmed != true) {
      AppLogger.debug('[Auth] 로그아웃 취소');
      return;
    }

    final success = await ref.read(authStateProvider.notifier).logout();

    if (!context.mounted) return;

    if (success) {
      // 회원탈퇴 쪽과 같은 이유로 한 프레임 미룬다(_handleDeleteAccount 참고).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    } else {
      showAndroidToast(context, '로그아웃에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    // 회원탈퇴 다이얼로그
    final confirmed = await showTwoButtonDialog(
      context,
      title: '회원 탈퇴하시겠습니까?',
      content: '탈퇴하면 저장한 여행지, 접근성 프로필 등\n계정 정보가 삭제되며 복구할 수 없습니다.',
      primaryLabel: '탈퇴하기',
      secondaryLabel: '취소',
    );
    if (confirmed != true) {
      AppLogger.debug('[Auth] 회원탈퇴 취소');
      return;
    }

    final success = await ref.read(authStateProvider.notifier).deleteAccount();

    if (!context.mounted) return;

    if (success) {
      // 탈퇴 처리 중 카카오/구글 재인증으로 외부 액티비티(카카오톡, 계정 선택
      // 팝업 등)에 갔다가 앱으로 막 돌아온 직후라, 그 복귀로 인한 위젯 정리가
      // 이 프레임에서 아직 안 끝났을 수 있다. 그 상태에서 바로
      // pushAndRemoveUntil로 여러 라우트를 한꺼번에 갈아치우면 위젯 트리
      // 정리가 꼬여 크래시가 날 수 있어(_dependents.isEmpty), 한 프레임
      // 미뤄서 그 정리가 끝난 뒤에 안전하게 전환한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    } else {
      showAndroidToast(context, '회원 탈퇴에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    // 마이페이지 탭 자체가 비로그인 사용자를 막아서(main_shell.dart의
    // kMemberOnlyTabs 게이트) user가 null인 경우는 실질적으로 없고, 여기서
    // '게스트'가 보일 수 있는 건 SSO 프로필에 닉네임이 없어 null로 들어온
    // 회원뿐이다 — 그런 경우를 게스트로 잘못 표시하지 않도록 구분한다.
    final nickname = user == null
        ? '게스트'
        : (user.nickname?.isNotEmpty ?? false)
        ? user.nickname!
        : '회원';
    final profiles = (user?.accessibilityProfiles ?? const [])
        .map(_profileFromName)
        .whereType<AccessibilityProfile>()
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24.h),
          Text(
            '안녕하세요, $nickname님!',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 23.h),
          _buildAccessibilityCard(context, profiles, user?.interestSidoCode),
          SizedBox(height: 15.h),
          _buildSection(
            title: '내 설정',
            items: [
              _MenuEntry(
                '접근성 프로필 설정',
                () => _openAccessibilitySetting(context),
              ),
            ],
          ),
          _buildSection(
            title: '정보 안내',
            items: [
              _MenuEntry('오픈소스 라이브러리', () => _openOpenSourceLicenses(context)),
              _MenuEntry(
                '이용약관',
                () => _openExternalLink(context, _termsOfServiceUrl),
              ),
              _MenuEntry(
                '개인정보처리방침',
                () => _openExternalLink(context, _privacyPolicyUrl),
              ),
            ],
          ),
          _buildSection(
            title: '참여 및 문의',
            items: [
              _MenuEntry('자주 묻는 질문', () => _openFaq(context)),
              _MenuEntry(
                '문의하기',
                () => _openExternalLink(context, _inquiryFormUrl),
              ),
            ],
          ),
          SizedBox(height: 11.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTextAction('로그아웃', () => _handleLogout(context, ref)),
              SizedBox(width: 96.w),
              _buildTextAction(
                '회원탈퇴',
                () => _handleDeleteAccount(context, ref),
              ),
            ],
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // 사용자의 현재 접근성 프로필을 보여주는 카드
  Widget _buildAccessibilityCard(
    BuildContext context,
    List<AccessibilityProfile> profiles,
    String? interestSidoCode,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 13.r),
      decoration: BoxDecoration(
        color: AppColors.myPageCardOverlay,
        borderRadius: BorderRadius.circular(9.2.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 접근성 프로필',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          if (profiles.isEmpty)
            Text(
              '접근성 프로필이 설정되지 않았습니다.\n프로필을 수정하여 접근성 프로필을 생성해 주세요.',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
          else
            for (final profile in profiles) _buildProfileRow(profile),
          if (interestSidoCode != null) _buildRegionRow(interestSidoCode),
          SizedBox(height: 16.h),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              label: '프로필 수정하기',
              button: true,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => _openAccessibilitySetting(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '프로필 수정하기',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10.r,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 관심 지역(시/도)을 보여주는 행. 시/군구는 카드에는 안 보여준다(요청사항).
  // area_codes.json에서 이름을 찾아야 해서(AreaCodeRepository.load) 비동기다
  // — 이미 캐시된 뒤라면 다음 프레임에 바로 채워진다.
  Widget _buildRegionRow(String interestSidoCode) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: FutureBuilder<List<AreaCode>>(
        future: AreaCodeRepository.load(),
        builder: (context, snapshot) {
          final areaCodes = snapshot.data ?? const [];
          AreaCode? sido;
          for (final area in areaCodes) {
            if (area.code == interestSidoCode) {
              sido = area;
              break;
            }
          }
          if (sido == null) return const SizedBox.shrink();
          return Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.pin_drop_outlined,
                  size: 18.r,
                  color: AppColors.toggleUnselected,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                sido.name,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileRow(AccessibilityProfile profile) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              profile.icon,
              size: 18.r,
              color: AppColors.toggleUnselected,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            profile.label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<_MenuEntry> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.mutedDivider, height: 1),
        SizedBox(height: 15.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 13.h),
        for (final item in items) _buildMenuItem(item),
        SizedBox(height: 13.h),
      ],
    );
  }

  Widget _buildMenuItem(_MenuEntry item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13.5.h),
      child: Semantics(
        label: item.label,
        button: true,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: item.onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextAction(String label, VoidCallback onTap) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w300,
            color: AppColors.textTertiary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}
