import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/mental_health_helpers.dart';
import '../models/mental_log_model.dart';
import '../providers/mental_health_provider.dart';

/// Modal bottom sheet for logging or editing 5-dimension daily mental wellbeing.
class MentalHealthFormModal extends ConsumerStatefulWidget {
  final DateTime targetDate;
  final MentalLogModel? existingLog;

  const MentalHealthFormModal({
    super.key,
    required this.targetDate,
    this.existingLog,
  });

  /// Static helper to open the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required DateTime targetDate,
    MentalLogModel? existingLog,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MentalHealthFormModal(
        targetDate: targetDate,
        existingLog: existingLog,
      ),
    );
  }

  @override
  ConsumerState<MentalHealthFormModal> createState() =>
      _MentalHealthFormModalState();
}

class _MentalHealthFormModalState extends ConsumerState<MentalHealthFormModal> {
  late double _anxiety;
  late double _happiness;
  late double _socialEnergy;
  late double _selfSatisfaction;
  late double _balance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    _anxiety = (log?.anxiety ?? 5).toDouble();
    _happiness = (log?.happiness ?? 5).toDouble();
    _socialEnergy = (log?.socialEnergy ?? 5).toDouble();
    _selfSatisfaction = (log?.selfSatisfaction ?? 5).toDouble();
    _balance = (log?.balance ?? 5).toDouble();
  }

  Future<void> _onSave() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final dateKey = MentalHealthHelpers.formatDateKey(widget.targetDate);
      final service = ref.read(mentalHealthServiceProvider);

      final resultId = await service.upsertMentalLog(
        uid: uid,
        dateKey: dateKey,
        anxiety: _anxiety.round().clamp(1, 10),
        happiness: _happiness.round().clamp(1, 10),
        socialEnergy: _socialEnergy.round().clamp(1, 10),
        selfSatisfaction: _selfSatisfaction.round().clamp(1, 10),
        balance: _balance.round().clamp(1, 10),
      );

      if (mounted) {
        if (resultId != null) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('mental_saved_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required Color accentColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.round()}/10',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: accentColor.withValues(alpha: 0.18),
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalBg = isDark ? const Color(0xFF08123A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final dateStr = MentalHealthHelpers.formatDateKey(widget.targetDate);

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.psychology_outlined,
                          size: 20,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('mental_modal_title'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Calm / Anxiety Slider
            _buildSliderRow(
              label: context.tr('slider_anxiety_label'),
              value: _anxiety,
              onChanged: (val) => setState(() => _anxiety = val),
              accentColor: const Color(0xFF00E5FF),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),

            // 2. Happiness Slider
            _buildSliderRow(
              label: context.tr('dimension_happiness'),
              value: _happiness,
              onChanged: (val) => setState(() => _happiness = val),
              accentColor: const Color(0xFFF59E0B),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),

            // 3. Social Energy Slider
            _buildSliderRow(
              label: context.tr('dimension_social_energy'),
              value: _socialEnergy,
              onChanged: (val) => setState(() => _socialEnergy = val),
              accentColor: const Color(0xFF10B981),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),

            // 4. Self Satisfaction Slider
            _buildSliderRow(
              label: context.tr('dimension_self_satisfaction'),
              value: _selfSatisfaction,
              onChanged: (val) => setState(() => _selfSatisfaction = val),
              accentColor: const Color(0xFF8B5CF6),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),

            // 5. Life Balance Slider
            _buildSliderRow(
              label: context.tr('dimension_balance'),
              value: _balance,
              onChanged: (val) => setState(() => _balance = val),
              accentColor: const Color(0xFFEC4899),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            const SizedBox(height: 12),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isLoading ? null : _onSave,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.tr('save'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
