import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/learning_path_model.dart';
import '../providers/learning_paths_provider.dart';

/// Row widget representing a single day's step in a learning path.
class PathStepRow extends ConsumerStatefulWidget {
  final LearningPathModel path;
  final PathStepModel step;

  const PathStepRow({super.key, required this.path, required this.step});

  @override
  ConsumerState<PathStepRow> createState() => _PathStepRowState();
}

class _PathStepRowState extends ConsumerState<PathStepRow> {
  bool _isSubStepsExpanded = false;
  final TextEditingController _newSubStepController = TextEditingController();
  bool _isAddingSubStep = false;

  @override
  void dispose() {
    _newSubStepController.dispose();
    super.dispose();
  }

  Future<void> _toggleDayCompletion() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    final service = ref.read(learningPathsServiceProvider);

    await service.toggleStepCompletion(
      uid: uid,
      path: widget.path,
      day: widget.step.day,
      context: context,
      ref: ref,
    );
  }

  Future<void> _toggleSubStep(String subStepId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    final service = ref.read(learningPathsServiceProvider);

    await service.toggleSubStepCompletion(
      uid: uid,
      path: widget.path,
      day: widget.step.day,
      subStepId: subStepId,
      context: context,
      ref: ref,
    );
  }

  Future<void> _addSubStep() async {
    final text = _newSubStepController.text.trim();
    if (text.isEmpty) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final service = ref.read(learningPathsServiceProvider);
    await service.addSubStep(
      uid: uid,
      path: widget.path,
      day: widget.step.day,
      subStepTitle: text,
    );

    if (mounted) {
      _newSubStepController.clear();
      setState(() => _isAddingSubStep = false);
    }
  }

  Future<void> _deleteSubStep(String subStepId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    final service = ref.read(learningPathsServiceProvider);

    await service.deleteSubStep(
      uid: uid,
      path: widget.path,
      day: widget.step.day,
      subStepId: subStepId,
      context: context,
      ref: ref,
    );
  }

  Future<void> _manualDayOverride() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    final service = ref.read(learningPathsServiceProvider);

    await service.manualDayOverride(
      uid: uid,
      path: widget.path,
      day: widget.step.day,
      completed: !widget.step.completed,
      context: context,
      ref: ref,
    );
  }

  Future<void> _editDayTitle() async {
    final titleController = TextEditingController(text: widget.step.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${dialogCtx.tr('day_label')} ${widget.step.day}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: TextStyle(color: primaryTextColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: dialogCtx.tr('day_topic_hint'),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF08123A)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(dialogCtx.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6FF2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () =>
                Navigator.of(dialogCtx).pop(titleController.text.trim()),
            child: Text(dialogCtx.tr('save')),
          ),
        ],
      ),
    );

    if (newTitle != null && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        final service = ref.read(learningPathsServiceProvider);
        await service.updateDayTitle(
          uid: uid,
          path: widget.path,
          day: widget.step.day,
          newTitle: newTitle,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final rowBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final step = widget.step;
    final hasSubSteps = step.subSteps.isNotEmpty;
    final isCompleted = step.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                  : const Color(0xFFECFDF5))
            : rowBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Step Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Day Number Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${context.tr('day_label')} ${step.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFF2E6FF2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Day Title
                Expanded(
                  child: InkWell(
                    onTap: _editDayTitle,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        step.title.isNotEmpty
                            ? step.title
                            : context.tr('day_untitled_placeholder'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: step.title.isNotEmpty
                              ? primaryTextColor
                              : secondaryTextColor.withValues(alpha: 0.6),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Sub-steps expand toggle (if has sub-steps)
                if (hasSubSteps)
                  InkWell(
                    onTap: () {
                      setState(
                        () => _isSubStepsExpanded = !_isSubStepsExpanded,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${step.completedSubStepsCount}/${step.subSteps.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2E6FF2),
                            ),
                          ),
                          Icon(
                            _isSubStepsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                // If no sub-steps: primary direct checkbox
                if (!hasSubSteps)
                  IconButton(
                    icon: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : secondaryTextColor,
                      size: 22,
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: _toggleDayCompletion,
                  )
                else
                  // If has sub-steps: secondary manual override action
                  IconButton(
                    icon: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : secondaryTextColor.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    tooltip: context.tr('manual_day_complete_tooltip'),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: _manualDayOverride,
                  ),
              ],
            ),
          ),

          // Sub-steps Checklist (when expanded or when adding a sub-step)
          if (hasSubSteps && _isSubStepsExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 12, 10),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  ...step.subSteps.map((sub) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _toggleSubStep(sub.id),
                            borderRadius: BorderRadius.circular(6),
                            child: Icon(
                              sub.completed
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 18,
                              color: sub.completed
                                  ? const Color(0xFF10B981)
                                  : secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sub.completed
                                    ? secondaryTextColor
                                    : primaryTextColor,
                                decoration: sub.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            color: secondaryTextColor,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => _deleteSubStep(sub.id),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Inline "+ Add sub-step" input
          if (_isAddingSubStep)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSubStepController,
                      autofocus: true,
                      style: TextStyle(fontSize: 12, color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: context.tr('substep_hint'),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F1B4C)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      onSubmitted: (_) => _addSubStep(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF2E6FF2),
                      size: 18,
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: _addSubStep,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () {
                      _newSubStepController.clear();
                      setState(() => _isAddingSubStep = false);
                    },
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 12, 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isAddingSubStep = true;
                    _isSubStepsExpanded = true;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: Color(0xFF2E6FF2),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('add_substep_btn'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E6FF2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
