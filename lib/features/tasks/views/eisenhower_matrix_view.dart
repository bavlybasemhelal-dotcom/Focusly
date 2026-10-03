import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../widgets/add_edit_task_sheet.dart';

/// The 2x2 Eisenhower Decision Matrix view with Drag & Drop between quadrants.
class EisenhowerMatrixView extends ConsumerWidget {
  final List<TaskModel> tasks;

  const EisenhowerMatrixView({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Partition tasks into their computed quadrants (pure logic)
    final q1Tasks = tasks
        .where((t) => t.computedQuadrant == EisenhowerQuadrant.q1DoNow)
        .toList();
    final q2Tasks = tasks
        .where((t) => t.computedQuadrant == EisenhowerQuadrant.q2Schedule)
        .toList();
    final q3Tasks = tasks
        .where((t) => t.computedQuadrant == EisenhowerQuadrant.q3Delegate)
        .toList();
    final q4Tasks = tasks
        .where((t) => t.computedQuadrant == EisenhowerQuadrant.q4Eliminate)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Grid of 4 quadrants (2 columns x 2 rows)
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
          child: Column(
            children: [
              // Top Row (Q1 & Q2)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuadrantBox(
                        quadrant: EisenhowerQuadrant.q1DoNow,
                        tasks: q1Tasks,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuadrantBox(
                        quadrant: EisenhowerQuadrant.q2Schedule,
                        tasks: q2Tasks,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Bottom Row (Q3 & Q4)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuadrantBox(
                        quadrant: EisenhowerQuadrant.q3Delegate,
                        tasks: q3Tasks,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuadrantBox(
                        quadrant: EisenhowerQuadrant.q4Eliminate,
                        tasks: q4Tasks,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Single Quadrant Box acting as both a list container and DragTarget
class _QuadrantBox extends ConsumerStatefulWidget {
  final EisenhowerQuadrant quadrant;
  final List<TaskModel> tasks;

  const _QuadrantBox({required this.quadrant, required this.tasks});

  @override
  ConsumerState<_QuadrantBox> createState() => _QuadrantBoxState();
}

class _QuadrantBoxState extends ConsumerState<_QuadrantBox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final quadrant = widget.quadrant;
    final accentColor = quadrant.accentColor;

    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = _isHovered
        ? accentColor
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F5));

    return DragTarget<TaskModel>(
      onWillAcceptWithDetails: (details) {
        return details.data.computedQuadrant != quadrant;
      },
      onMove: (_) {
        if (!_isHovered) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onLeave: (_) {
        if (_isHovered) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      onAcceptWithDetails: (details) async {
        setState(() {
          _isHovered = false;
        });

        final task = details.data;
        await ref
            .read(tasksControllerProvider)
            .moveTaskToQuadrant(task, quadrant, context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.tr('task_moved_to')} ${context.tr(quadrant.titleKey)}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: _isHovered ? 2.0 : 1.2,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Accent Strip & Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(quadrant.badgeIcon, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(quadrant.titleKey),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            context.tr(quadrant.subtitleKey),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Counter Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.tasks.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Quick Add Task Button for this Quadrant
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              AddEditTaskSheet(initialQuadrant: quadrant),
                        );
                      },
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Quadrant Tasks List / Encouraging Empty State
              Expanded(
                child: widget.tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            context.tr(quadrant.emptyKey),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        itemCount: widget.tasks.length,
                        itemBuilder: (context, index) {
                          final task = widget.tasks[index];
                          return _DraggableTaskItem(
                            task: task,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draggable task card inside an Eisenhower quadrant
class _DraggableTaskItem extends ConsumerWidget {
  final TaskModel task;
  final bool isDark;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const _DraggableTaskItem({
    required this.task,
    required this.isDark,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemWidget = Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Small Checkbox
          SizedBox(
            width: 16,
            height: 16,
            child: Checkbox(
              value: task.done,
              activeColor: AppColors.brandPrimary(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              onChanged: (_) {
                ref.read(tasksControllerProvider).toggleTaskDone(task, context);
              },
            ),
          ),
          const SizedBox(width: 6),

          // Task Title
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: task.done ? secondaryTextColor : primaryTextColor,
                decoration: task.done ? TextDecoration.lineThrough : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<TaskModel>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary(context).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: AppColors.brandPrimary(context),
              width: 1.5,
            ),
          ),
          child: Text(
            task.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: itemWidget),
      child: itemWidget,
    );
  }
}
