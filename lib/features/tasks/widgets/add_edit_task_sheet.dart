import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../para/providers/para_provider.dart';
import '../../skills/providers/skills_provider.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import '../providers/tasks_provider.dart';

/// Modal bottom sheet for creating a new task or editing an existing one.
class AddEditTaskSheet extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;
  final EisenhowerQuadrant? initialQuadrant;
  final String? initialTitle;
  final String? initialProjectId;

  const AddEditTaskSheet({
    super.key,
    this.taskToEdit,
    this.initialQuadrant,
    this.initialTitle,
    this.initialProjectId,
  });

  /// Convenient helper to open the Add/Edit Task Sheet
  static Future<bool?> show(
    BuildContext context, {
    TaskModel? taskToEdit,
    EisenhowerQuadrant? initialQuadrant,
    String? initialTitle,
    String? initialProjectId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditTaskSheet(
        taskToEdit: taskToEdit,
        initialQuadrant: initialQuadrant,
        initialTitle: initialTitle,
        initialProjectId: initialProjectId,
      ),
    );
  }

  @override
  ConsumerState<AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends ConsumerState<AddEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late String _selectedCategoryId;
  late TaskPriority _selectedPriority;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedDeadline;
  String? _selectedProjectId;
  String? _selectedSkillId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;

    _titleController =
        TextEditingController(text: task?.title ?? (widget.initialTitle ?? ''));
    _notesController = TextEditingController(text: task?.notes ?? '');
    _selectedCategoryId = task?.categoryId ?? 'work';
    _selectedPriority = task?.priority ?? TaskPriority.medium;
    _selectedDate = task?.date ?? DateTime.now();
    _selectedTime = task?.time;
    _selectedDeadline = task?.deadline;
    _selectedProjectId = task?.projectId ?? widget.initialProjectId;
    _selectedSkillId = task?.skillId;

    // If opened with an initial quadrant pre-selected, apply its defaults
    if (task == null && widget.initialQuadrant != null) {
      _applyQuadrantQuickSelect(widget.initialQuadrant!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyQuadrantQuickSelect(EisenhowerQuadrant quadrant) {
    setState(() {
      final dummy = TaskModel(
        id: '',
        title: '',
        categoryId: _selectedCategoryId,
        priority: _selectedPriority,
        date: _selectedDate,
        createdAt: DateTime.now(),
      );
      final applied = applyQuadrantRule(dummy, quadrant);
      _selectedPriority = applied.priority;
      _selectedDate = applied.date;
      if (quadrant == EisenhowerQuadrant.q4Eliminate) {
        _selectedDeadline = null;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    final controller = ref.read(tasksControllerProvider);

    if (widget.taskToEdit != null) {
      final updated = widget.taskToEdit!.copyWith(
        title: title,
        notes: notes,
        categoryId: _selectedCategoryId,
        priority: _selectedPriority,
        date: _selectedDate,
        time: _selectedTime,
        deadline: _selectedDeadline,
        projectId: _selectedProjectId,
        skillId: _selectedSkillId,
        clearTime: _selectedTime == null,
        clearDeadline: _selectedDeadline == null,
        clearProjectId: _selectedProjectId == null,
        clearSkillId: _selectedSkillId == null,
      );
      await controller.updateTask(updated, context);
    } else {
      final newTask = TaskModel(
        id: '',
        title: title,
        notes: notes,
        categoryId: _selectedCategoryId,
        priority: _selectedPriority,
        date: _selectedDate,
        time: _selectedTime,
        deadline: _selectedDeadline,
        done: false,
        subtasks: const [],
        createdAt: DateTime.now(),
        projectId: _selectedProjectId,
        skillId: _selectedSkillId,
      );
      await controller.addTask(newTask, context);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Opens dialog to create a new custom category
  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    int selectedColor = 0xFF2563EB;
    final List<int> palette = [
      0xFF2563EB, // Royal Blue
      0xFF8B5CF6, // Purple
      0xFF10B981, // Emerald
      0xFFEC4899, // Pink
      0xFF0EA5E9, // Sky Blue
      0xFFF59E0B, // Amber
      0xFFEF4444, // Red
      0xFF64748B, // Slate
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.tr('add_category_title'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('category_name_hint'),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('select_color'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: palette.map((colorVal) {
                      final isSelected = selectedColor == colorVal;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = colorVal;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(colorVal),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(colorVal).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      await ref
                          .read(tasksControllerProvider)
                          .addCustomCategory(name, selectedColor);
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlueVibrant,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(context.tr('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = AppColors.border(context);

    final categoriesAsync = ref.watch(categoriesProvider);
    final categoriesList = categoriesAsync.value ?? TaskCategory.defaultCategories;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.taskToEdit != null
                          ? context.tr('edit_task')
                          : context.tr('new_task'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. Task Title Input
                TextFormField(
                  controller: _titleController,
                  autofocus: widget.taskToEdit == null,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('task_title_required');
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('task_title_hint'),
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brandPrimary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Notes Field (Optional)
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: context.tr('task_notes_hint'),
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brandPrimary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Quick Eisenhower Matrix Quadrant Selector
                _buildFieldLabel(context.tr('quick_quadrant_select'), primaryTextColor),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EisenhowerQuadrant.values.map((quadrant) {
                    return GestureDetector(
                      onTap: () => _applyQuadrantQuickSelect(quadrant),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: quadrant.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: quadrant.accentColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(quadrant.badgeIcon, size: 14, color: quadrant.accentColor),
                            const SizedBox(width: 6),
                            Text(
                              context.tr(quadrant.titleKey),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: quadrant.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 4. Category Selector
                _buildFieldLabel(context.tr('category'), primaryTextColor),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...categoriesList.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        final catName = cat.isDefault ? context.tr(cat.nameKey) : cat.nameKey;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8.0),
                          child: ChoiceChip(
                            label: Text(catName),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                            ),
                            selected: isSelected,
                            selectedColor: cat.color,
                            backgroundColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? cat.color : borderColor,
                                width: 1.2,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategoryId = cat.id;
                                });
                              }
                            },
                          ),
                        );
                      }),
                      // Add Custom Category Button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandPrimary.withValues(alpha: 0.15),
                          ),
                          child: Icon(Icons.add, size: 18, color: brandPrimary),
                        ),
                        onPressed: _showAddCategoryDialog,
                        tooltip: context.tr('add_category_title'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Priority Selector
                _buildFieldLabel(context.tr('priority'), primaryTextColor),
                const SizedBox(height: 8),
                Row(
                  children: TaskPriority.values.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPriority = priority;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? priority.color.withValues(alpha: isDark ? 0.25 : 0.15)
                                  : (isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? priority.color : borderColor,
                                width: isSelected ? 1.8 : 1.2,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: priority.color,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr(priority.titleKey),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? priority.color : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 6. Date, Time & Deadline Selectors Row
                Row(
                  children: [
                    // Scheduled Date Picker
                    Expanded(
                      child: _buildPickerButton(
                        label: context.tr('date'),
                        value: DateFormat.MMMd().format(_selectedDate),
                        icon: Icons.calendar_today_rounded,
                        color: brandPrimary,
                        isDark: isDark,
                        borderColor: borderColor,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Optional Scheduled Time Picker
                    Expanded(
                      child: _buildPickerButton(
                        label: context.tr('time'),
                        value: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : context.tr('all_day'),
                        icon: Icons.access_time_rounded,
                        color: const Color(0xFF0EA5E9),
                        isDark: isDark,
                        borderColor: borderColor,
                        hasClear: _selectedTime != null,
                        onClear: () {
                          setState(() {
                            _selectedTime = null;
                          });
                        },
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedTime = picked;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Optional Deadline Picker
                _buildPickerButton(
                  label: context.tr('deadline'),
                  value: _selectedDeadline != null
                      ? DateFormat.yMMMd().add_jm().format(_selectedDeadline!)
                      : context.tr('no_deadline'),
                  icon: Icons.flag_rounded,
                  color: AppColors.errorRed,
                  isDark: isDark,
                  borderColor: borderColor,
                  hasClear: _selectedDeadline != null,
                  onClear: () {
                    setState(() {
                      _selectedDeadline = null;
                    });
                  },
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 18, minute: 0),
                      );
                      final hour = pickedTime?.hour ?? 23;
                      final minute = pickedTime?.minute ?? 59;
                      setState(() {
                        _selectedDeadline = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          hour,
                          minute,
                        );
                      });
                    }
                  },
                ),
                // Optional PARA Project Link
                _buildFieldLabel(context.tr('link_to_project_label'), primaryTextColor),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final projectsAsync = ref.watch(paraProjectsStreamProvider);
                    final secondaryTextColor = AppColors.textSecondary(context);
                    return projectsAsync.when(
                      data: (projects) {
                        if (projects.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, color: secondaryTextColor, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr('no_active_projects_hint'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryTextColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: projects.any((p) => p.id == _selectedProjectId)
                                  ? _selectedProjectId
                                  : null,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                              hint: Row(
                                children: [
                                  Icon(Icons.folder_outlined, color: secondaryTextColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('no_project_linked'),
                                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                  ),
                                ],
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    context.tr('no_project_linked'),
                                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                  ),
                                ),
                                ...projects.map((p) {
                                  return DropdownMenuItem<String?>(
                                    value: p.id,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.folder_special_rounded, color: Color(0xFF2E6FF2), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            p.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedProjectId = val;
                                });
                              },
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // =========================================================
                // Optional Link to Skill (Skills Board Feature)
                // =========================================================
                _buildFieldLabel(context.tr('link_to_skill_label'), primaryTextColor),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final skillsAsync = ref.watch(skillsStreamProvider);
                    final secondaryTextColor = AppColors.textSecondary(context);
                    return skillsAsync.when(
                      data: (skills) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: skills.any((s) => s.id == _selectedSkillId)
                                  ? _selectedSkillId
                                  : null,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                              hint: Row(
                                children: [
                                  Icon(Icons.psychology_outlined, color: secondaryTextColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('no_skill_linked'),
                                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                  ),
                                ],
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    context.tr('no_skill_linked'),
                                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                  ),
                                ),
                                ...skills.map((s) {
                                  return DropdownMenuItem<String?>(
                                    value: s.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Color(s.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${s.name} (Lvl ${s.level})',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedSkillId = val;
                                });
                              },
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // 7. Save / Update Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.cyanElectric.withValues(alpha: 0.35)
                            : const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: isDark ? const Color(0xFF060B24) : Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            widget.taskToEdit != null
                                ? context.tr('update_task')
                                : context.tr('create_task'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
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

  Widget _buildFieldLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  Widget _buildPickerButton({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTap,
    bool hasClear = false,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasClear)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.clear_rounded, size: 16, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
