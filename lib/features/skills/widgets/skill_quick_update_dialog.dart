import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/skill_math_helper.dart';
import '../models/skill_model.dart';
import '../providers/skills_provider.dart';

/// Lightweight quick progress update dialog for modifying a skill's level and XP.
class SkillQuickUpdateDialog extends ConsumerStatefulWidget {
  final SkillModel skill;

  const SkillQuickUpdateDialog({super.key, required this.skill});

  /// Static helper to show the dialog.
  static Future<void> show(BuildContext context, SkillModel skill) {
    return showDialog(
      context: context,
      builder: (_) => SkillQuickUpdateDialog(skill: skill),
    );
  }

  @override
  ConsumerState<SkillQuickUpdateDialog> createState() =>
      _SkillQuickUpdateDialogState();
}

class _SkillQuickUpdateDialogState
    extends ConsumerState<SkillQuickUpdateDialog> {
  late TextEditingController _levelController;
  late TextEditingController _xpController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(
      text: widget.skill.level.toString(),
    );
    _xpController = TextEditingController(text: widget.skill.xp.toString());
  }

  @override
  void dispose() {
    _levelController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final rawLevel =
        int.tryParse(_levelController.text.trim()) ?? widget.skill.level;
    final validLevel = rawLevel >= 1 ? rawLevel : 1;

    final rawXp = int.tryParse(_xpController.text.trim()) ?? widget.skill.xp;
    final validXp = rawXp >= 0 ? rawXp : 0;

    setState(() => _isLoading = true);

    // Calculate progression and rollover
    final norm = SkillMathHelper.normalizeDirectInput(
      levelInput: validLevel,
      xpInput: validXp,
      previousLevel: widget.skill.level,
    );

    final service = ref.read(skillsServiceProvider);
    final success = await service.updateSkill(
      uid: uid,
      skill: widget.skill,
      levelInput: validLevel,
      xpInput: validXp,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();

        if (norm.didLevelUp) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'skill_level_up_toast',
                  args: {
                    'level': norm.newLevel.toString(),
                    'skillName': widget.skill.name,
                  },
                ),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('skill_updated_toast')),
              backgroundColor: const Color(0xFF2E6FF2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(widget.skill.color).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: Color(widget.skill.color),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('quick_update_skill_title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              'quick_update_skill_subtitle',
              args: {'skillName': widget.skill.name},
            ),
            style: TextStyle(fontSize: 13, color: secondaryTextColor),
          ),
          const SizedBox(height: 16),

          // Inputs Row (Level + XP)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('skill_level_label'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _levelController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E6FF2),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('skill_xp_label'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _xpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        suffixText: '/ 100',
                        suffixStyle: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E6FF2),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.tr('cancel'),
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(widget.skill.color),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  context.tr('save'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}
