import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';
import '../../widgets/toast.dart';
import '../auth/login_screen.dart';
import 'accessibility_screen.dart';

AccessibilityProfile? _profileFromName(String name) {
  for (final profile in AccessibilityProfile.values) {
    if (profile.name == name) return profile;
  }
  return null;
}

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  void _showNotReady(BuildContext context) {
    showAndroidToast(context, '준비 중인 기능입니다.');
  }

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
    // TODO: 로그아웃 확인 다이얼로그. 일단 주석 처리.
    // final confirmed = await showTwoButtonDialog(
    //   context,
    //   title: '로그아웃',
    //   content: '로그아웃하시겠습니까?',
    //   primaryLabel: '로그아웃',
    //   secondaryLabel: '취소',
    // );
    // if (confirmed != true) {
    //   AppLogger.debug('[Auth] 로그아웃 취소');
    //   return;
    // }

    final provider = ref.read(authStateProvider).user?.provider;
    final notifier = ref.read(authStateProvider.notifier);
    AppLogger.debug('[Auth] 로그아웃 시도 (provider=$provider)');

    final success = switch (provider) {
      'kakao' => await notifier.logoutKakao(),
      'google' => await notifier.logoutGoogle(),
      _ => false,
    };

    if (!context.mounted) return;

    if (success) {
      AppLogger.info('[Auth] 로그아웃 완료 (provider=$provider)');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      AppLogger.warning('[Auth] 로그아웃 실패 (provider=$provider)');
      showAndroidToast(context, '로그아웃에 실패했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    // TODO: 회원탈퇴 확인 다이얼로그. 일단 주석 처리.
    // final confirmed = await showTwoButtonDialog(
    //   context,
    //   title: '회원탈퇴',
    //   content: '탈퇴 시 계정 정보와 이용 기록이 모두 삭제되며 복구할 수 없습니다.\n탈퇴하시겠습니까?',
    //   primaryLabel: '탈퇴',
    //   secondaryLabel: '취소',
    // );
    // if (confirmed != true) {
    //   AppLogger.debug('[Auth] 회원탈퇴 취소');
    //   return;
    // }

    final provider = ref.read(authStateProvider).user?.provider;
    final notifier = ref.read(authStateProvider.notifier);
    AppLogger.debug('[Auth] 회원탈퇴 시도 (provider=$provider)');

    final success = switch (provider) {
      'kakao' => await notifier.deleteKakaoAccount(),
      'google' => await notifier.deleteGoogleAccount(),
      _ => false,
    };

    if (!context.mounted) return;

    if (success) {
      AppLogger.info('[Auth] 회원탈퇴 완료 (provider=$provider)');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      AppLogger.warning('[Auth] 회원탈퇴 실패 (provider=$provider)');
      showAndroidToast(context, '회원탈퇴에 실패했습니다. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final nickname = user?.nickname ?? '게스트';
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
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 23.h),
          _buildAccessibilityCard(context, profiles),
          SizedBox(height: 15.h),
          _buildSection(
            title: '내 설정',
            items: [
              _MenuEntry(
                '접근성 프로필 설정',
                () => _openAccessibilitySetting(context),
              ),
              _MenuEntry('앱 접근성 설정', () => _showNotReady(context)),
            ],
          ),
          _buildSection(
            title: '정보 안내',
            items: [
              _MenuEntry('접근성 정보 기준', () => _showNotReady(context)),
              _MenuEntry('오픈소스 라이브러리', () => _showNotReady(context)),
              _MenuEntry('이용약관', () => _showNotReady(context)),
              _MenuEntry('개인정보처리방침', () => _showNotReady(context)),
            ],
          ),
          _buildSection(
            title: '참여 및 문의',
            items: [
              _MenuEntry('FAQ', () => _showNotReady(context)),
              _MenuEntry('문의하기', () => _showNotReady(context)),
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

  Widget _buildAccessibilityCard(
    BuildContext context,
    List<AccessibilityProfile> profiles,
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
              '접근성 프로필이 설정되지 않았습니다.\n프로필을 수정하여 접근성 프로필을 생성해주세요.',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
          else
            for (final profile in profiles) _buildProfileRow(profile),
          SizedBox(height: 16.h),
          Align(
            alignment: Alignment.centerRight,
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
                    Icons.chevron_right,
                    size: 10.r,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(AccessibilityProfile profile) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(profile.icon, size: 18.r, color: const Color(0xFF7D7D7D)),
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
    );
  }

  Widget _buildTextAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w300,
          color: const Color(0xFF8B8B8B),
          decoration: TextDecoration.underline,
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
