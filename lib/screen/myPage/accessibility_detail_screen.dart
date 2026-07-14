import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/accessibility/accessibility_field.dart';
import '../../model/accessibility/accessibility_field_mapping.dart';
import '../../model/accessibility/accessibility_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/app_dialog.dart';

const _kProfileOrder = [
  AccessibilityProfile.physicalAssist,
  AccessibilityProfile.visionAssist,
  AccessibilityProfile.hearingAssist,
  AccessibilityProfile.strollerCompanion,
  AccessibilityProfile.seniorCompanion,
];

const _kCurrentStep = 2;
const _kTotalSteps = 2;

class AccessibilityDetailScreen extends ConsumerStatefulWidget {
  const AccessibilityDetailScreen({
    super.key,
    required this.selectedProfiles,
    required this.onComplete,
  });

  final Set<AccessibilityProfile> selectedProfiles;

  /// 저장을 마치거나 건너뛰었을 때 호출된다. 진입 경로에 따라 호출부에서
  /// 홈 화면 이동, 이전 화면으로 복귀 등을 결정한다.
  final VoidCallback onComplete;

  @override
  ConsumerState<AccessibilityDetailScreen> createState() =>
      _AccessibilityDetailScreenState();
}

class _AccessibilityDetailScreenState
    extends ConsumerState<AccessibilityDetailScreen> {
  final _userService = UserService();
  final Set<AccessibilityField> _selectedFields = {};
  final Set<AccessibilityProfile> _selectAllProfiles = {};

  void _toggleSelection(
    AccessibilityProfile profile,
    AccessibilityField field,
  ) {
    setState(() {
      if (_selectedFields.contains(field)) {
        _selectedFields.remove(field);
      } else {
        _selectedFields.add(field);
      }
      // 개별 필드를 직접 고르면 그 profile의 '전체' 선택은 해제된다.
      _selectAllProfiles.remove(profile);
    });
  }

  void _toggleSelectAll(AccessibilityProfile profile) {
    setState(() {
      if (_selectAllProfiles.contains(profile)) {
        _selectAllProfiles.remove(profile);
      } else {
        _selectAllProfiles.add(profile);
        // '전체'를 고르면 그 profile 안에서 개별로 골라둔 필드는 해제된다.
        final categoryFields =
            AccessibilityFieldMapping.mapping[profile] ?? const [];
        _selectedFields.removeWhere(categoryFields.contains);
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
    widget.onComplete();
  }

  bool _hasSelectionFor(AccessibilityProfile profile) {
    if (_selectAllProfiles.contains(profile)) return true;
    final categoryFields = AccessibilityFieldMapping.mapping[profile] ?? const [];
    return categoryFields.any(_selectedFields.contains);
  }

  /// profile별로 개별 선택된 필드가 있으면 그 필드만, 없으면(전체 선택 혹은
  /// 미선택) 해당 profile의 전체 필드를 저장 대상으로 확정한다.
  List<AccessibilityField> _resolveFields(List<AccessibilityProfile> profiles) {
    final resolved = <AccessibilityField>{};
    for (final profile in profiles) {
      final categoryFields = AccessibilityFieldMapping.mapping[profile] ?? const [];
      final individuallySelected = categoryFields.where(
        _selectedFields.contains,
      );
      if (individuallySelected.isNotEmpty) {
        resolved.addAll(individuallySelected);
      } else {
        resolved.addAll(categoryFields);
      }
    }
    return resolved.toList();
  }

  Future<void> _handleSave(List<AccessibilityProfile> profiles) async {
    final hasUnselectedProfile = profiles.any(
      (profile) => !_hasSelectionFor(profile),
    );

    if (hasUnselectedProfile) {
      final confirmed = await showTwoButtonDialog(
        context,
        content: '무장애 정보를 선택하지 않은 경우 전체 항목을 기준으로 정보가 제공됩니다.',
        primaryLabel: '확인',
        secondaryLabel: '취소',
      );
      if (confirmed != true) return;
    }

    final currentUser = ref.read(authStateProvider).user;
    if (currentUser == null) {
      AppLogger.error('[AccessibilityDetailScreen] 로그인된 유저 정보가 없어 저장을 건너뜀');
      if (!mounted) return;
      widget.onComplete();
      return;
    }

    final updatedUser = currentUser.copyWith(
      accessibilityProfiles: profiles.map((p) => p.name).toList(),
      accessibilityFields: _resolveFields(
        profiles,
      ).map((f) => f.name).toList(),
    );

    try {
      await _userService.updateUser(updatedUser);
      ref.read(authStateProvider.notifier).setUser(updatedUser);
    } catch (e) {
      if (!mounted) return;
      await showInfoDialog(context, content: '저장에 실패했습니다. 다시 시도해주세요.');
      return;
    }

    if (!mounted) return;
    await showInfoDialog(
      context,
      content: '접근성 프로필이 저장되었습니다.\n마이페이지에서 수정할 수 있습니다.',
    );

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final orderedProfiles = _kProfileOrder
        .where((profile) => widget.selectedProfiles.contains(profile))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '이전',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                '필요하신 무장애 정보를 선택해주세요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '선택해주신 항목 기준으로 정보를 안내해드려요',
                style: TextStyle(fontSize: 16, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: orderedProfiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 28),
                  itemBuilder: (context, index) =>
                      _buildSection(orderedProfiles[index]),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: () => _handleSave(orderedProfiles),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0065F4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '저장하기',
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

  Widget _buildSection(AccessibilityProfile profile) {
    final fields = AccessibilityFieldMapping.mapping[profile] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(profile.icon, size: 20, color: const Color(0xFF0065F4)),
            const SizedBox(width: 6),
            Text(
              profile.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildAllChip(profile),
            ...fields.map((field) => _buildChip(profile, field)),
          ],
        ),
      ],
    );
  }

  Widget _buildAllChip(AccessibilityProfile profile) {
    final isSelected = _selectAllProfiles.contains(profile);
    return _chip(
      label: '전체',
      isSelected: isSelected,
      onTap: () => _toggleSelectAll(profile),
    );
  }

  Widget _buildChip(AccessibilityProfile profile, AccessibilityField field) {
    final isSelected = _selectedFields.contains(field);
    return _chip(
      label: field.label,
      isSelected: isSelected,
      onTap: () => _toggleSelection(profile, field),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0065F4) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF7D7D7D),
          ),
        ),
      ),
    );
  }
}
