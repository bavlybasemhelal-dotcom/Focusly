import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/group_member_model.dart';
import '../../providers/groups_provider.dart';
import '../services/group_assignment_service.dart';

/// Modal bottom sheet allowing Group Admins to assign a Task or Habit
/// directly to one, multiple, or all approved group members.
class AssignmentFormModal extends ConsumerStatefulWidget {
  final String groupId;

  const AssignmentFormModal({super.key, required this.groupId});

  /// Convenient helper to display the Assignment Form Modal
  static Future<bool?> show(BuildContext context, {required String groupId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignmentFormModal(groupId: groupId),
    );
  }

  @override
  ConsumerState<AssignmentFormModal> createState() =>
      _AssignmentFormModalState();
}

class _AssignmentFormModalState extends ConsumerState<AssignmentFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetCountController = TextEditingController(text: '5');

  String _selectedType = 'task'; // 'task' | 'habit'
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  String _completionMode = 'simple'; // 'simple' | 'count'

  final Set<String> _selectedMemberUids = {};
  bool _isSaving = false;
  final String _requestId = FirebaseFirestore.instance
      .collection('groups')
      .doc()
      .id;

  @override
  void dispose() {
    _titleController.dispose();
    _targetCountController.dispose();
    super.dispose();
  }

  void _selectAllMembers(List<GroupMemberModel> approved) {
    setState(() {
      if (_selectedMemberUids.length == approved.length) {
        _selectedMemberUids.clear();
      } else {
        _selectedMemberUids.clear();
        _selectedMemberUids.addAll(approved.map((m) => m.uid));
      }
    });
  }

  Future<void> _handleSave(List<GroupMemberModel> approved) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMemberUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
          content: Text(
            context.tr('select_at_least_one_member'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      return;
    }

    final selectedMembers = approved
        .where((m) => _selectedMemberUids.contains(m.uid))
        .toList();

    int? targetCount;
    if (_completionMode == 'count') {
      targetCount = int.tryParse(_targetCountController.text.trim());
      if (targetCount == null || targetCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.errorRed,
            content: Text(
              context.tr('invalid_target_count'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    DateTime deadline = _selectedDate;
    if (_selectedTime != null) {
      deadline = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    try {
      await GroupAssignmentService().createAssignment(
        groupId: widget.groupId,
        requestId: _requestId,
        type: _selectedType,
        title: _titleController.text.trim(),
        deadline: deadline,
        completionMode: _completionMode,
        targetCount: targetCount,
        selectedMembers: selectedMembers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text(
              context.tr('assignment_created_success'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.errorRed,
            content: Text(
              '${context.tr('error')}: $e',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
    final brandPrimary = AppColors.brandPrimary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F5);

    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: membersAsync.when(
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                context.tr('members_load_error'),
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
          ),
          data: (members) {
            final approved = members.where((m) => m.isApproved).toList();

            return SingleChildScrollView(
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
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: brandPrimary.withValues(
                                  alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.assignment_turned_in_rounded,
                                color: brandPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('assign_task_habit_title'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. TYPE SELECTOR (Task vs Habit)
                    _buildSectionLabel(
                      context.tr('assignment_type_label'),
                      primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeChip(
                          type: 'task',
                          title: context.tr('assignment_type_task'),
                          icon: Icons.check_circle_outline_rounded,
                          isSelected: _selectedType == 'task',
                          brandPrimary: brandPrimary,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildTypeChip(
                          type: 'habit',
                          title: context.tr('assignment_type_habit'),
                          icon: Icons.repeat_rounded,
                          isSelected: _selectedType == 'habit',
                          brandPrimary: brandPrimary,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. TITLE INPUT
                    _buildSectionLabel(
                      _selectedType == 'task'
                          ? context.tr('task_title')
                          : context.tr('habit_title_label'),
                      primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return context.tr('task_title_required');
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: _selectedType == 'task'
                            ? context.tr('task_title_hint')
                            : context.tr('habit_title_hint'),
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF08123A)
                            : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: brandPrimary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. DATE & TIME PICKER (Deadline for task, Start Date for habit)
                    _buildSectionLabel(
                      context.tr('deadline_label'),
                      primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Date Button
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: brandPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat.yMMMd().format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Time Button (Optional)
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    _selectedTime ??
                                    const TimeOfDay(hour: 18, minute: 0),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedTime = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedTime != null
                                          ? _selectedTime!.format(context)
                                          : context.tr('all_day'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (_selectedTime != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedTime = null;
                                        });
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 4. COMPLETION MODE (Simple vs Target Count)
                    _buildSectionLabel(
                      context.tr('completion_mode_label'),
                      primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildModeChip(
                          mode: 'simple',
                          title: context.tr('completion_mode_simple'),
                          subtitle: context.tr('completion_mode_simple_sub'),
                          icon: Icons.check_circle_rounded,
                          isSelected: _completionMode == 'simple',
                          brandPrimary: brandPrimary,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _buildModeChip(
                          mode: 'count',
                          title: context.tr('completion_mode_count'),
                          subtitle: context.tr('completion_mode_count_sub'),
                          icon: Icons.pin_rounded,
                          isSelected: _completionMode == 'count',
                          brandPrimary: brandPrimary,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 5. TARGET COUNT INPUT (Only when mode == 'count')
                    if (_completionMode == 'count') ...[
                      _buildSectionLabel(
                        context.tr('target_count_label'),
                        primaryTextColor,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _targetCountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                        validator: (val) {
                          if (_completionMode == 'count') {
                            final parsed = int.tryParse(val?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return context.tr('invalid_target_count');
                            }
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. 5',
                          hintStyle: TextStyle(
                            color: secondaryTextColor.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF08123A)
                              : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: borderColor,
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: brandPrimary,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // 6. ASSIGN TO MEMBERS (Multi-select list with Select All)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionLabel(
                          '${context.tr('assign_to_label')} (${_selectedMemberUids.length}/${approved.length})',
                          primaryTextColor,
                        ),
                        TextButton(
                          onPressed: () => _selectAllMembers(approved),
                          child: Text(
                            _selectedMemberUids.length == approved.length
                                ? context.tr('deselect_all')
                                : context.tr('select_all'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: approved.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: borderColor),
                        itemBuilder: (context, idx) {
                          final member = approved[idx];
                          final isSelected = _selectedMemberUids.contains(
                            member.uid,
                          );

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMemberUids.add(member.uid);
                                } else {
                                  _selectedMemberUids.remove(member.uid);
                                }
                              });
                            },
                            dense: true,
                            activeColor: brandPrimary,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text(
                              member.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            secondary: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? brandPrimary
                                    : (isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFE2E8F0)),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 7. SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _handleSave(approved),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('assign_now_btn'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildTypeChip({
    required String type,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color brandPrimary,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? brandPrimary.withValues(alpha: isDark ? 0.25 : 0.12)
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? brandPrimary : borderColor,
              width: isSelected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? brandPrimary
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? brandPrimary
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color brandPrimary,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _completionMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? brandPrimary.withValues(alpha: isDark ? 0.22 : 0.12)
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? brandPrimary : borderColor,
              width: isSelected ? 1.8 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? brandPrimary : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected
                          ? brandPrimary
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
