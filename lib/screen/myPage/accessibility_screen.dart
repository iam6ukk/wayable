import 'package:flutter/material.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/toast.dart';
import '../home_screen.dart';
import 'accessibility_detail_screen.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.strollerCompanion,
  AccessibilityProfile.seniorCompanion,
];

const _kCurrentStep = 1;
const _kTotalSteps = 2;

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  final Set<AccessibilityProfile> _selectedProfiles = {};

  void _toggleSelection(AccessibilityProfile profile) {
    setState(() {
      if (_selectedProfiles.contains(profile)) {
        _selectedProfiles.remove(profile);
      } else {
        _selectedProfiles.add(profile);
      }
    });
  }

  Future<void> _handleSkip(BuildContext context) async {
    final skip = await showTwoButtonDialog(
      context,
      content:
          '접근성 프로필을 설정하면 나에게 맞는 장소를 쉽게 찾을 수 있어요.\n\n'
          '마이페이지에서 언제든 다시 설정할 수 있습니다.',
      primaryLabel: '건너뛰기',
      secondaryLabel: '취소하기',
    );
    if (skip != true || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              const SizedBox(height: 16),
              Row(
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      children: [
                        TextSpan(
                          text: '$_kCurrentStep',
                          style: TextStyle(color: Color(0xFF0065F4)),
                        ),
                        TextSpan(text: '/$_kTotalSteps'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _handleSkip(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9A9A9A),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('건너뛰기', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _kCurrentStep / _kTotalSteps,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE3E3E3),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0065F4)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '뫄뫄님의 관심유형을 선택해주세요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '선택해주신 관심유형에 맞춰 추천해드려요',
                style: TextStyle(fontSize: 16, color: Color(0xFF6F6F6F)),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOption(_kProfileOrder[0]),
                          _buildOption(_kProfileOrder[1]),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildOption(_kProfileOrder[2]),
                          _buildOption(_kProfileOrder[3]),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildOption(_kProfileOrder[4]),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedProfiles.isEmpty) {
                      showAndroidToast(context, '하나 이상의 관심 유형을 선택해주세요.');
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccessibilityDetailScreen(
                          selectedProfiles: _selectedProfiles,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0065F4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '다음으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(AccessibilityProfile profile) {
    final isSelected = _selectedProfiles.contains(profile);

    return GestureDetector(
      onTap: () => _toggleSelection(profile),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF0065F4)
                    : const Color(0xFFF2F2F2),
              ),
              child: Icon(
                profile.icon,
                size: 48,
                color: isSelected ? Colors.white : const Color(0xFF7D7D7D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
