import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/life_area_assessment_model.dart';
import '../providers/life_areas_provider.dart';

/// Bottom sheet modal for creating and updating Wheel of Life assessments
class AssessmentFormModal extends ConsumerStatefulWidget {
  final LifeAreaAssessmentModel? assessmentToEdit;

  const AssessmentFormModal({super.key, this.assessmentToEdit});

  static Future<void> show(
    BuildContext context, {
    LifeAreaAssessmentModel? assessmentToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AssessmentFormModal(assessmentToEdit: assessmentToEdit),
    );
  }

  @override
  ConsumerState<AssessmentFormModal> createState() =>
      _AssessmentFormModalState();
}

class _AssessmentFormModalState extends ConsumerState<AssessmentFormModal> {
  late DateTime _selectedDate;
  late int _career;
  late int _finance;
  late int _health;
  late int _family;
  late int _romance;
  late int _growth;
  late int _fun;
  late int _environment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.assessmentToEdit;
    _selectedDate = edit?.date ?? DateTime.now();
    _career = edit?.career ?? 5;
    _finance = edit?.finance ?? 5;
    _health = edit?.health ?? 5;
    _family = edit?.family ?? 5;
    _romance = edit?.romance ?? 5;
    _growth = edit?.growth ?? 5;
    _fun = edit?.fun ?? 5;
    _environment = edit?.environment ?? 5;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0F172A),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAssessment() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final uid = ref.read(currentUserIdProvider);
    if (uid == null || uid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final service = ref.read(lifeAreasServiceProvider);
    final isEdit = widget.assessmentToEdit != null;

    if (isEdit) {
      final updated = widget.assessmentToEdit!.copyWith(
        date: _selectedDate,
        career: _career,
        finance: _finance,
        health: _health,
        family: _family,
        romance: _romance,
        growth: _growth,
        fun: _fun,
        environment: _environment,
      );
      await service.updateAssessment(uid, updated);
    } else {
      final newAssessment = LifeAreaAssessmentModel(
        id: '',
        date: _selectedDate,
        career: _career,
        finance: _finance,
        health: _health,
        family: _family,
        romance: _romance,
        growth: _growth,
        fun: _fun,
        environment: _environment,
        createdAt: DateTime.now(),
      );
      await service.addAssessment(uid, newAssessment);
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteAssessment() async {
    final edit = widget.assessmentToEdit;
    if (edit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_assessment_dialog_title')),
        content: Text(
          context.tr(
            'delete_assessment_dialog_msg',
            args: {'date': edit.formattedDate},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('delete_assessment_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(lifeAreasServiceProvider).deleteAssessment(uid, edit.id);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final modalBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final isEdit = widget.assessmentToEdit != null;

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formattedDate =
        '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr(
                        isEdit
                            ? 'edit_assessment_title'
                            : 'add_assessment_title',
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),

              // Date Picker Tile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('assessment_date_label'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 8 Sliders
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_career',
                icon: '💼',
                value: _career,
                color: const Color(0xFF3B82F6),
                onChanged: (v) => setState(() => _career = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_finance',
                icon: '💰',
                value: _finance,
                color: const Color(0xFF10B981),
                onChanged: (v) => setState(() => _finance = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_health',
                icon: '💪',
                value: _health,
                color: const Color(0xFFEF4444),
                onChanged: (v) => setState(() => _health = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_family',
                icon: '👨‍👩‍👧‍👦',
                value: _family,
                color: const Color(0xFFF59E0B),
                onChanged: (v) => setState(() => _family = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_romance',
                icon: '❤️',
                value: _romance,
                color: const Color(0xFFEC4899),
                onChanged: (v) => setState(() => _romance = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_growth',
                icon: '🌱',
                value: _growth,
                color: const Color(0xFF8B5CF6),
                onChanged: (v) => setState(() => _growth = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_fun',
                icon: '🎉',
                value: _fun,
                color: const Color(0xFF06B6D4),
                onChanged: (v) => setState(() => _fun = v),
              ),
              _buildSliderRow(
                context: context,
                labelKey: 'dimension_environment',
                icon: '🏡',
                value: _environment,
                color: const Color(0xFF14B8A6),
                onChanged: (v) => setState(() => _environment = v),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _isSaving ? null : _saveAssessment,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              context.tr('save_assessment_btn'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          context.tr('delete_assessment_btn'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isSaving ? null : _deleteAssessment,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String labelKey,
    required String icon,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    context.tr(labelKey),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$value / 10',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: isDark
                  ? Colors.white12
                  : const Color(0xFFE2E8F0),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (newVal) {
                HapticFeedback.selectionClick();
                onChanged(newVal.round());
              },
            ),
          ),
        ],
      ),
    );
  }
}
