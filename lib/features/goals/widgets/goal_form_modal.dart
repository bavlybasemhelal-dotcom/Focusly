import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../para/providers/para_provider.dart';
import '../models/goal_model.dart';
import '../providers/goals_provider.dart';
import 'goal_card.dart';

/// Modal bottom sheet for creating or editing a Goal.
class GoalFormModal extends ConsumerStatefulWidget {
  final GoalModel? goal;

  const GoalFormModal({
    super.key,
    this.goal,
  });

  static Future<void> show(BuildContext context, {GoalModel? goal}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalFormModal(goal: goal),
    );
  }

  @override
  ConsumerState<GoalFormModal> createState() => _GoalFormModalState();
}

class _GoalFormModalState extends ConsumerState<GoalFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _milestoneInputController = TextEditingController();

  late String _selectedIcon;
  late String _selectedColor;
  late String _selectedTimeframe;
  String? _selectedAreaId;
  DateTime? _selectedTargetDate;
  int _manualProgress = 0;
  List<GoalMilestone> _milestones = [];
  bool _isSaving = false;

  static const List<String> _iconPresets = [
    '🎯', '🚀', '💼', '💡', '🏆', '📚', '💰', '🏋️', '🧘', '🌍', '🏠', '🎨'
  ];

  static const List<String> _colorPresets = [
    '#2563EB', // Radiant Blue
    '#7C3AED', // Vivid Purple
    '#EC4899', // Pink
    '#F59E0B', // Amber
    '#10B981', // Emerald Green
    '#06B6D4', // Electric Cyan
    '#EF4444', // Red
    '#8B5CF6', // Indigo
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _titleController = TextEditingController(text: g?.title ?? '');
    _selectedIcon = g?.icon ?? '🎯';
    _selectedColor = g?.color ?? '#2563EB';
    _selectedTimeframe = g?.timeframe ?? '1month';
    _selectedAreaId = g?.areaId;
    _selectedTargetDate = g?.targetDate;
    _manualProgress = g?.progress ?? 0;
    _milestones = g != null ? List<GoalMilestone>.from(g.milestones) : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _milestoneInputController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.goal != null;

  void _addMilestone() {
    final title = _milestoneInputController.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _milestones.add(GoalMilestone(title: title));
      _milestoneInputController.clear();
    });
  }

  void _removeMilestone(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _milestones.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final effectiveProgress = calculateMilestoneProgress(_milestones, _manualProgress);

    bool success;
    if (_isEditMode) {
      final updated = widget.goal!.copyWith(
        title: title,
        icon: _selectedIcon,
        color: _selectedColor,
        timeframe: _selectedTimeframe,
        areaId: _selectedAreaId,
        clearAreaId: _selectedAreaId == null,
        targetDate: _selectedTargetDate,
        clearTargetDate: _selectedTargetDate == null,
        progress: effectiveProgress,
        milestones: _milestones,
      );
      success = await ref.read(goalsServiceProvider).updateGoal(
            uid: uid,
            goal: updated,
          );
    } else {
      final newId = await ref.read(goalsServiceProvider).addGoal(
            uid: uid,
            title: title,
            icon: _selectedIcon,
            color: _selectedColor,
            timeframe: _selectedTimeframe,
            areaId: _selectedAreaId,
            targetDate: _selectedTargetDate,
            progress: effectiveProgress,
            milestones: _milestones,
          );
      success = newId != null;
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? context.tr('goal_updated_toast')
                  : context.tr('goal_created_toast'),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final areasAsync = ref.watch(paraAreasStreamProvider);
    final areas = areasAsync.value ?? [];

    final targetDateDisplay = _selectedTargetDate == null
        ? context.tr('no_target_date_selected')
        : DateFormat.yMMMMd().format(_selectedTargetDate!);

    final timeframes = [
      {'key': '1month', 'label': context.tr('timeframe_1month')},
      {'key': '3months', 'label': context.tr('timeframe_3months')},
      {'key': '1year', 'label': context.tr('timeframe_1year')},
      {'key': '5years', 'label': context.tr('timeframe_5years')},
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
          child: Form(
            key: _formKey,
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

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode
                          ? context.tr('edit_goal_title')
                          : context.tr('add_goal_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title Input (Required)
                Text(
                  context.tr('goal_title_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: context.tr('goal_title_hint'),
                    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
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
                      borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.tr('goal_title_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Icon / Emoji Selector
                Text(
                  context.tr('goal_icon_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _iconPresets.map((emoji) {
                      final isSelected = _selectedIcon == emoji;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedIcon = emoji;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E6FF2).withValues(alpha: 0.15)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2E6FF2)
                                    : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Color Palette Selector
                Text(
                  context.tr('goal_color_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _colorPresets.map((hex) {
                      final color = parseGoalColor(hex);
                      final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedColor = hex;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(Icons.check, size: 18, color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Timeframe Selector Chips
                Text(
                  context.tr('goal_timeframe_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeframes.map((tf) {
                    final key = tf['key']!;
                    final label = tf['label']!;
                    final isSelected = _selectedTimeframe == key;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTimeframe = key;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2E6FF2).withValues(alpha: 0.15)
                              : inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2E6FF2) : borderColor,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF2E6FF2) : primaryTextColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Linked PARA Area Dropdown
                Text(
                  context.tr('goal_linked_area_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedAreaId,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                      hint: Text(
                        context.tr('none_area_optional'),
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            context.tr('none_area_optional'),
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        ),
                        ...areas.map((area) {
                          return DropdownMenuItem<String?>(
                            value: area.id,
                            child: Row(
                              children: [
                                Text(area.emoji, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  area.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedAreaId = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Target Date Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('goal_target_date_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    if (_selectedTargetDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTargetDate = null;
                          });
                        },
                        child: Text(context.tr('clear_date_btn')),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedTargetDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2050),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedTargetDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, color: Color(0xFF2E6FF2), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          targetDateDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Progress Slider (Shown when no milestones exist)
                if (_milestones.isEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('goal_progress_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        '$_manualProgress%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6FF2),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _manualProgress.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF2E6FF2),
                    inactiveColor: inputBg,
                    onChanged: (val) {
                      setState(() {
                        _manualProgress = val.round();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // Milestones Sub-section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('goal_milestones_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    if (_milestones.isNotEmpty)
                      Text(
                        '${calculateMilestoneProgress(_milestones)}% ${context.tr('auto_calculated_suffix')}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Milestones Dynamic List
                ..._milestones.asMap().entries.map((entry) {
                  final index = entry.key;
                  final milestone = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          milestone.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: milestone.done ? const Color(0xFF10B981) : secondaryTextColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            milestone.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                              decoration: milestone.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: secondaryTextColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeMilestone(index),
                        ),
                      ],
                    ),
                  );
                }),

                // Add Milestone Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _milestoneInputController,
                        style: TextStyle(color: primaryTextColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.tr('add_milestone_hint'),
                          hintStyle: TextStyle(
                            color: secondaryTextColor.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: inputBg,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onFieldSubmitted: (_) => _addMilestone(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addMilestone,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2E6FF2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Goal Button
                Container(
                  width: double.infinity,
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
                    onPressed: _isSaving ? null : _handleSave,
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
                            _isEditMode
                                ? context.tr('update_goal_btn')
                                : context.tr('save_goal_btn'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
