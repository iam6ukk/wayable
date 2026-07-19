import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast.dart';
import '../auth/login_screen.dart';
import 'accessibility_screen.dart';

const _kCardColor = Color(0xB2F7F7F7);
const _kGreyText = Color(0xFF6F6F6F);
const _kDividerColor = Color(0xFFE3E3E3);

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
    await ref.read(authStateProvider.notifier).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            '안녕하세요, $nickname님!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF060606),
            ),
          ),
          const SizedBox(height: 20),
          _buildAccessibilityCard(context, profiles),
          const SizedBox(height: 24),
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
              _MenuEntry('접근성 정보 제보', () => _showNotReady(context)),
              _MenuEntry('문의하기', () => _showNotReady(context)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTextAction('로그아웃', () => _handleLogout(context, ref)),
              const SizedBox(width: 48),
              _buildTextAction('회원탈퇴', () => _showNotReady(context)),
            ],
          ),
          const SizedBox(height: 24),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 접근성 프로필',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (profiles.isEmpty)
            const Text(
              '접근성 프로필이 설정되지 않았습니다.\n프로필을 수정하여 접근성 프로필을 생성해주세요.',
              style: TextStyle(fontSize: 16, color: _kGreyText, height: 1.4),
            )
          else
            for (final profile in profiles) _buildProfileRow(profile),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _openAccessibilitySetting(context),
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '프로필 수정하기',
                    style: TextStyle(fontSize: 13, color: _kGreyText),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: _kGreyText),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(profile.icon, size: 20, color: const Color(0xFF7D7D7D)),
          const SizedBox(width: 8),
          Text(
            profile.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _kGreyText,
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
        const Divider(color: _kDividerColor, height: 1),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items) _buildMenuItem(item),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMenuItem(_MenuEntry item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          item.label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
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
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF8B8B8B),
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
