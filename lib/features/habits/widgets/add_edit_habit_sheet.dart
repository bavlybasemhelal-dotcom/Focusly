import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/habit_model.dart';
import '../providers/habits_provider.dart';

/// Modal bottom sheet for creating a new Habit or editing an existing one in Focusly.
///
/// Supports title, habit stacking trigger cue, daily reminder time,
/// and collapsible advanced weekly reset controls.
class AddEditHabitSheet extends ConsumerStatefulWidget {
  final HabitModel? habitToEdit;

  const AddEditHabitSheet({super.key, this.habitToEdit});

  @override
  ConsumerState<AddEditHabitSheet> createState() => _AddEditHabitSheetState();
}

class _AddEditHabitSheetState extends ConsumerState<AddEditHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _stackTriggerController;

  TimeOfDay? _selectedTime;
  int _resetDay = DateTime.saturday;
  bool _autoReset = true;
  bool _isAdvancedExpanded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final habit = widget.habitToEdit;
    _titleController = TextEditingController(text: habit?.title ?? '');
    _stackTriggerController = TextEditingController(
      text: habit?.stackTrigger ?? '',
    );
    _selectedTime = habit?.time;
    _resetDay = habit?.resetDay ?? DateTime.saturday;
    _autoReset = habit?.autoReset ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _stackTriggerController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final stackTrigger = _stackTriggerController.text.trim().isNotEmpty
        ? _stackTriggerController.text.trim()
        : null;

    try {
      final controller = ref.read(habitsControllerProvider);

      if (widget.habitToEdit != null) {
        final updated = widget.habitToEdit!.copyWith(
          title: title,
          stackTrigger: stackTrigger,
          clearStackTrigger: stackTrigger == null,
          time: _selectedTime,
          clearTime: _selectedTime == null,
          resetDay: _resetDay,
          autoReset: _autoReset,
        );
        if (!mounted) return;
        if (!await controller.updateHabit(updated, context)) {
          throw StateError('Save failed');
        }
      } else {
        final newHabit = HabitModel.create(
          id: '',
          title: title,
          stackTrigger: stackTrigger,
          time: _selectedTime,
          resetDay: _resetDay,
          autoReset: _autoReset,
        );
        if (!mounted) return;
        if (!await controller.addHabit(newHabit, context)) {
          throw StateError('Save failed');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('habit_error_saving'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: Color(0xFF38BDF8),
                    surface: Color(0xFF0F1B4C),
                  )
                : const ColorScheme.light(primary: Color(0xFF2E6FF2)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);

    final isEdit = widget.habitToEdit != null;
    final isLocked = widget.habitToEdit?.locked == true;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle Pill
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Sheet Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? context.tr('edit_habit') : context.tr('new_habit'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    tooltip: context.tr('cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Group Assigned Info Banner
              if (isLocked) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF0284C7,
                    ).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.group_rounded,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.tr('assigned_by_badge')}: ${widget.habitToEdit?.assignedByName ?? context.tr('role_admin')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            Text(
                              context.tr('locked_field_tooltip'),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Habit Title Input
              TextFormField(
                controller: _titleController,
                readOnly: isLocked,
                style: TextStyle(
                  color: isLocked ? secondaryTextColor : primaryTextColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('habit_title_hint'),
                  hintStyle: TextStyle(color: secondaryTextColor, fontSize: 15),
                  filled: true,
                  fillColor: isLocked
                      ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                      : cardBg,
                  suffixIcon: isLocked
                      ? Tooltip(
                          message: context.tr('locked_field_tooltip'),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  prefixIcon: Icon(
                    Icons.local_fire_department_rounded,
                    color: isLocked
                        ? secondaryTextColor
                        : const Color(0xFFF59E0B),
                    size: 22,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isLocked ? borderColor : brandPrimary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return context.tr('habit_title_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // 2. Habit Stacking Trigger Input
              Text(
                context.tr('stack_trigger_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _stackTriggerController,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('stack_trigger_hint'),
                  hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                  filled: true,
                  fillColor: cardBg,
                  prefixIcon: Icon(
                    Icons.tips_and_updates_rounded,
                    color: const Color(0xFF38BDF8),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: brandPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Explanatory caption for habit stacking
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('stack_trigger_help'),
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Daily Reminder Time Picker
              Text(
                context.tr('reminder_time_optional'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
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
                      Icon(
                        Icons.alarm_rounded,
                        color: _selectedTime != null
                            ? brandPrimary
                            : secondaryTextColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : context.tr('no_reminder_set'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedTime != null
                                ? primaryTextColor
                                : secondaryTextColor,
                          ),
                        ),
                      ),
                      if (_selectedTime != null)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: secondaryTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedTime = null;
                            });
                          },
                        )
                      else
                        Text(
                          context.tr('set_time'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: brandPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Collapsible Advanced Options (Reset Day & Auto Reset)
              if (isEdit) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _isAdvancedExpanded = !_isAdvancedExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('advanced_options'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _isAdvancedExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isAdvancedExpanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Auto-Reset Switch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('auto_reset_title'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    context.tr('auto_reset_desc'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _autoReset,
                              activeTrackColor: brandPrimary,
                              onChanged: (val) {
                                setState(() {
                                  _autoReset = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
              ],

              // 5. Submit / Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isEdit
                                  ? context.tr('update_habit')
                                  : context.tr('create_habit'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFF060B24)
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
