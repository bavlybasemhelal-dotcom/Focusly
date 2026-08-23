import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../energy_mood/providers/energy_mood_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/ritual_model.dart';
import '../providers/rituals_provider.dart';

/// Guided 5-step modal wizard for the End-of-Day Shutdown Ritual.
class ShutdownWizardModal extends ConsumerStatefulWidget {
  final RitualModel? existingRitual;

  const ShutdownWizardModal({
    super.key,
    this.existingRitual,
  });

  static Future<void> show(BuildContext context) async {
    HapticFeedback.lightImpact();

    // Check optional timing nudge
    final container = ProviderScope.containerOf(context, listen: false);
    final preferredTime = container.read(preferredShutdownTimeSettingProvider);
    final now = TimeOfDay.now();

    final nowMinutes = now.hour * 60 + now.minute;
    final prefMinutes = preferredTime.hour * 60 + preferredTime.minute;

    if (nowMinutes < prefMinutes) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final formattedPref = preferredTime.format(context);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            dialogCtx.tr('early_shutdown_warning_title'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(dialogCtx),
            ),
          ),
          content: Text(
            dialogCtx.tr(
              'early_shutdown_warning_msg',
              args: {'time': formattedPref},
            ),
            style: TextStyle(color: AppColors.textSecondary(dialogCtx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(dialogCtx.tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(dialogCtx.tr('continue_btn')),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShutdownWizardModal(),
    );
  }

  @override
  ConsumerState<ShutdownWizardModal> createState() => _ShutdownWizardModalState();
}

class _ShutdownWizardModalState extends ConsumerState<ShutdownWizardModal> {
  int _currentStep = 0; // 0 = Review, 1 = Plan, 2 = Checkin, 3 = Lesson, 4 = Gratitude
  bool _isSaving = false;

  // Step 2: Plan Tomorrow
  final TextEditingController _task1Controller = TextEditingController();
  final TextEditingController _task2Controller = TextEditingController();
  final TextEditingController _task3Controller = TextEditingController();

  // Step 3: Energy & Mood
  int _energyLevel = 3;
  String _mood = '🙂';

  // Step 4: Lesson Learned
  final TextEditingController _lessonController = TextEditingController();

  // Step 5: Gratitude
  final TextEditingController _gratitude1Controller = TextEditingController();
  final TextEditingController _gratitude2Controller = TextEditingController();
  final TextEditingController _gratitude3Controller = TextEditingController();
  String? _gratitudeError;

  static const List<Map<String, dynamic>> _energyOptions = [
    {'level': 1, 'icon': Icons.battery_1_bar_rounded, 'color': Color(0xFFEF4444)},
    {'level': 2, 'icon': Icons.battery_2_bar_rounded, 'color': Color(0xFFF97316)},
    {'level': 3, 'icon': Icons.battery_4_bar_rounded, 'color': Color(0xFFFBBF24)},
    {'level': 4, 'icon': Icons.battery_5_bar_rounded, 'color': Color(0xFF10B981)},
    {'level': 5, 'icon': Icons.battery_full_rounded, 'color': Color(0xFF06B6D4)},
  ];

  static const List<String> _moodOptions = ['😞', '😐', '🙂', '😊', '🤩'];

  @override
  void initState() {
    super.initState();
    _loadExistingCheckinValues();
  }

  void _loadExistingCheckinValues() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkinAsync = ref.read(todayCheckinStreamProvider);
      final checkin = checkinAsync.value;
      if (checkin != null && mounted) {
        setState(() {
          _energyLevel = checkin.energy;
          _mood = checkin.mood;
        });
      }
    });
  }

  @override
  void dispose() {
    _task1Controller.dispose();
    _task2Controller.dispose();
    _task3Controller.dispose();
    _lessonController.dispose();
    _gratitude1Controller.dispose();
    _gratitude2Controller.dispose();
    _gratitude3Controller.dispose();
    super.dispose();
  }

  Future<void> _handlePostponeTasks(List<TaskModel> todayTasks) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    final count = await ref.read(ritualsServiceProvider).postponeUnfinishedTasksToTomorrow(
          uid: uid,
          tasks: todayTasks,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? context.tr('tasks_postponed_toast', args: {'count': count.toString()})
                : context.tr('no_unfinished_tasks_toast'),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleFinish() async {
    final g1 = _gratitude1Controller.text.trim();
    final g2 = _gratitude2Controller.text.trim();
    final g3 = _gratitude3Controller.text.trim();

    if (g1.isEmpty || g2.isEmpty || g3.isEmpty) {
      setState(() {
        _gratitudeError = context.tr('gratitude_all_required_error');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final dateStr = ref.read(todayDateStringProvider);

    setState(() {
      _isSaving = true;
      _gratitudeError = null;
    });

    final success = await ref.read(ritualsServiceProvider).finishShutdownRitual(
          uid: uid,
          dateStr: dateStr,
          energyLevel: _energyLevel,
          mood: _mood,
          gratitude1: g1,
          gratitude2: g2,
          gratitude3: g3,
          lesson: _lessonController.text.trim(),
          tomorrowTaskTitles: [
            _task1Controller.text.trim(),
            _task2Controller.text.trim(),
            _task3Controller.text.trim(),
          ],
          ref: ref,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('shutdown_completed_celebration_toast')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final ritualAsync = ref.watch(todayRitualStreamProvider);
    final isAlreadyCompleted = ritualAsync.value?.isShutdownCompleted == true;

    // If already closed out today, render friendly already-completed screen
    if (isAlreadyCompleted) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),
              const Text('🌙', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                context.tr('already_closed_today_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('already_closed_today_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: secondaryTextColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6FF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  context.tr('close'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? [];
    final today = DateTime.now();
    final todayTasks = allTasks.where((t) {
      return t.date.year == today.year &&
          t.date.month == today.month &&
          t.date.day == today.day;
    }).toList();

    final completedTasksCount = todayTasks.where((t) => t.done).length;

    final stepTitles = [
      context.tr('shutdown_step_1_title'),
      context.tr('shutdown_step_2_title'),
      context.tr('shutdown_step_3_title'),
      context.tr('shutdown_step_4_title'),
      context.tr('shutdown_step_5_title'),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Stepper Progress + Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentStep + 1} / 5',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E6FF2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        stepTitles[_currentStep],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Linear Progress Indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 5.0,
                  backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E6FF2)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 20),

              // Step Content Switching
              if (_currentStep == 0)
                _buildStep1Review(
                  context: context,
                  todayTasks: todayTasks,
                  completedCount: completedTasksCount,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 1)
                _buildStep2PlanTomorrow(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 2)
                _buildStep3Checkin(
                  context: context,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 3)
                _buildStep4Lesson(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                )
              else if (_currentStep == 4)
                _buildStep5Gratitude(
                  context: context,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  inputBg: inputBg,
                ),

              const SizedBox(height: 24),

              // Bottom Navigation Actions
              Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTextColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        context.tr('back_btn'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : (_currentStep == 4 ? _handleFinish : _nextStep),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _currentStep == 4
                                    ? context.tr('finish_shutdown_btn')
                                    : context.tr('continue_btn'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: Review Today ---
  Widget _buildStep1Review({
    required BuildContext context,
    required List<TaskModel> todayTasks,
    required int completedCount,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('shutdown_step_1_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(
                    'today_task_completion_summary',
                    args: {
                      'completed': completedCount.toString(),
                      'total': todayTasks.length.toString(),
                    },
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Postpone action button
        OutlinedButton.icon(
          onPressed: () => _handlePostponeTasks(todayTasks),
          icon: const Icon(Icons.forward_rounded, size: 18, color: Color(0xFF2E6FF2)),
          label: Text(
            context.tr('postpone_tasks_btn'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E6FF2)),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2E6FF2)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Plan Tomorrow ---
  Widget _buildStep2PlanTomorrow({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('shutdown_step_2_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        _buildTaskInputField(
          controller: _task1Controller,
          hint: context.tr('tomorrow_task_1_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildTaskInputField(
          controller: _task2Controller,
          hint: context.tr('tomorrow_task_2_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildTaskInputField(
          controller: _task3Controller,
          hint: context.tr('tomorrow_task_3_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _buildTaskInputField({
    required TextEditingController controller,
    required String hint,
    required Color inputBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor.withValues(alpha: 0.6)),
        filled: true,
        fillColor: inputBg,
        prefixIcon: const Icon(Icons.check_box_outline_blank_rounded, size: 20, color: Color(0xFF2E6FF2)),
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
          borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // --- Step 3: Quick Check-In (Energy & Mood) ---
  Widget _buildStep3Checkin({
    required BuildContext context,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('shutdown_step_3_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),

        // Energy Selector
        Text(
          context.tr('energy_level_title'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryTextColor),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _energyOptions.map((opt) {
            final lvl = opt['level'] as int;
            final icon = opt['icon'] as IconData;
            final color = opt['color'] as Color;
            final isSelected = _energyLevel == lvl;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _energyLevel = lvl;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.2) : inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Icon(icon, color: isSelected ? color : secondaryTextColor, size: 24),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Mood Selector
        Text(
          context.tr('mood_title'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryTextColor),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _moodOptions.map((emoji) {
            final isSelected = _mood == emoji;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _mood = emoji;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2E6FF2).withValues(alpha: 0.15) : inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2E6FF2) : borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Step 4: Lesson Learned ---
  Widget _buildStep4Lesson({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('shutdown_step_4_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lessonController,
          maxLines: 3,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
          decoration: InputDecoration(
            hintText: context.tr('lesson_learned_hint'),
            hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor.withValues(alpha: 0.6)),
            filled: true,
            fillColor: inputBg,
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
              borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // --- Step 5: Gratitude ---
  Widget _buildStep5Gratitude({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('shutdown_step_5_sub'),
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        if (_gratitudeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _gratitudeError!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
          ),
        ],
        const SizedBox(height: 16),

        _buildGratitudeField(
          controller: _gratitude1Controller,
          number: '1',
          hint: context.tr('gratitude_1_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildGratitudeField(
          controller: _gratitude2Controller,
          number: '2',
          hint: context.tr('gratitude_2_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
        const SizedBox(height: 10),
        _buildGratitudeField(
          controller: _gratitude3Controller,
          number: '3',
          hint: context.tr('gratitude_3_hint'),
          inputBg: inputBg,
          borderColor: borderColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _buildGratitudeField({
    required TextEditingController controller,
    required String number,
    required String hint,
    required Color inputBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor.withValues(alpha: 0.6)),
        filled: true,
        fillColor: inputBg,
        prefixIcon: Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E6FF2),
            ),
          ),
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
          borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
