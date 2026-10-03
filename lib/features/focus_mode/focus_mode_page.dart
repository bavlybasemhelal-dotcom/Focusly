import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../pomodoro/providers/pomodoro_provider.dart';
import '../pomodoro/widgets/circular_timer_ring.dart';
import '../pomodoro/widgets/pomodoro_controls.dart';
import '../tasks/models/task_model.dart';
import '../tasks/providers/tasks_provider.dart';
import 'providers/focus_mode_provider.dart';
import 'services/notification_queue.dart';

/// Full-screen, distraction-minimizing Focus Mode overlay.
///
/// Wraps the active Pomodoro timer session in a focused, minimal-chrome presentation
/// and provides a live checklist of the active task's subtasks in real time.
///
/// FEATURES:
/// 1. Full-screen presentation (hides app navigation bars).
/// 2. Task Linking & Compact Selector (pick or switch active tasks without leaving Focus Mode).
/// 3. Live Subtasks Checklist (toggling subtasks syncs directly with Firestore in real time).
/// 4. Inline Celebration on Task Completion (with quick "Choose Next Task" transition).
/// 5. Exit Commitment Guard (locks exit during running work sessions with a translated reminder toast).
/// 6. Notification Suppression (silences and queues in-app celebration dialogs until session ends).
class FocusModePage extends ConsumerStatefulWidget {
  const FocusModePage({super.key});

  @override
  ConsumerState<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends ConsumerState<FocusModePage> {
  final TextEditingController _newSubtaskController = TextEditingController();
  bool _isAddingSubtask = false;

  @override
  void initState() {
    super.initState();
    // Enable Focus Mode active flag on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(focusModeActiveProvider.notifier).enterFocusMode();
    });
  }

  @override
  void dispose() {
    _newSubtaskController.dispose();
    super.dispose();
  }

  /// Attempts to exit Focus Mode with commitment guard check
  void _tryExitFocusMode() {
    final timerState = ref.read(pomodoroTimerProvider);

    // Guard: Block exit if a work phase session is actively counting down
    if (timerState.isRunning && timerState.isWorkPhase) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('focus_mode_locked_toast'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Deactivate Focus Mode and flush any suppressed notifications
    ref.read(focusModeActiveProvider.notifier).exitFocusMode();
    Navigator.of(context).pop();

    // Flush any celebratory dialogs queued while in Focus Mode
    NotificationQueue().flush(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    final timerState = ref.watch(pomodoroTimerProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? [];

    // Find linked task if any
    TaskModel? linkedTask;
    if (timerState.selectedTaskId != null) {
      final matches = allTasks.where((t) => t.id == timerState.selectedTaskId);
      if (matches.isNotEmpty) {
        linkedTask = matches.first;
      }
    }

    // Background gradient
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF060B26), Color(0xFF0A1238), Color(0xFF0F1B4C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6), Color(0xFFE2E8F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return PopScope(
      canPop: !(timerState.isRunning && timerState.isWorkPhase),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(focusModeActiveProvider.notifier).exitFocusMode();
          NotificationQueue().flush(context);
        } else {
          _tryExitFocusMode();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                // -------------------------------------------------------------
                // 1. MINIMAL HEADER ROW
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Focus Mode badge & title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: brandPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.center_focus_strong_rounded,
                              color: brandPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('focus_mode_title'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: primaryTextColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.tr('distraction_free_badge'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Exit Guard Button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: IconButton(
                          icon: Icon(
                            timerState.isRunning && timerState.isWorkPhase
                                ? Icons.lock_outline_rounded
                                : Icons.close_rounded,
                            color:
                                timerState.isRunning && timerState.isWorkPhase
                                ? const Color(0xFFEF4444)
                                : secondaryTextColor,
                            size: 22,
                          ),
                          tooltip: context.tr('exit_focus_mode_btn'),
                          onPressed: _tryExitFocusMode,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.transparent),

                // -------------------------------------------------------------
                // 2. SCROLLABLE FOCUS CONTENT
                // -------------------------------------------------------------
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // -----------------------------------------------------
                        // A. TASK SELECTOR / ACTIVE TASK CARD
                        // -----------------------------------------------------
                        if (linkedTask == null)
                          _buildTaskSelector(
                            context,
                            allTasks,
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                          )
                        else
                          _buildActiveTaskCard(
                            context,
                            linkedTask,
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                            brandPrimary,
                          ),

                        const SizedBox(height: 20),

                        // -----------------------------------------------------
                        // B. CIRCULAR TIMER RING (REUSED)
                        // -----------------------------------------------------
                        CircularTimerRing(timerState: timerState),

                        const SizedBox(height: 24),

                        // -----------------------------------------------------
                        // C. POMODORO CONTROLS (REUSED)
                        // -----------------------------------------------------
                        PomodoroControls(timerState: timerState),

                        const SizedBox(height: 24),

                        // -----------------------------------------------------
                        // D. LIVE SUBTASKS CHECKLIST (If task linked)
                        // -----------------------------------------------------
                        if (linkedTask != null)
                          _buildSubtasksChecklist(
                            context,
                            linkedTask,
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                            brandPrimary,
                          ),

                        const SizedBox(height: 24),
                      ],
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

  /// Compact Task Selector when no task is linked
  Widget _buildTaskSelector(
    BuildContext context,
    List<TaskModel> allTasks,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final activeTasks = allTasks
        .where((t) => !t.done && t.listType == null)
        .toList();
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_add_check_rounded,
                color: Color(0xFF2E6FF2),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('select_task_to_focus'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activeTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                context.tr('no_active_tasks_to_focus'),
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeTasks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final task = activeTasks[index];
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(pomodoroTimerProvider.notifier)
                          .setSelectedTask(task.id, task.title);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0A1238)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: task.priority.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (task.subtasks.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${task.completedSubtasksCount}/${task.subtasks.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryTextColor,
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
        ],
      ),
    );
  }

  /// Prominent Active Task Card
  Widget _buildActiveTaskCard(
    BuildContext context,
    TaskModel task,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color brandPrimary,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);
    final isTaskFullyDone =
        task.done ||
        (task.subtasks.isNotEmpty &&
            task.completedSubtasksCount == task.subtasks.length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTaskFullyDone ? const Color(0xFF10B981) : borderColor,
          width: isTaskFullyDone ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isTaskFullyDone
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with priority & switch button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: task.priority.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr(task.priority.titleKey).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: task.priority.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (isTaskFullyDone) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('status_completed').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Switch / Clear Task Button
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(pomodoroTimerProvider.notifier)
                      .setSelectedTask(null, null);
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  context.tr('choose_next_task'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  foregroundColor: brandPrimary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Task Title with complete checkbox
          Row(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(tasksControllerProvider)
                      .toggleTaskDone(task, context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: task.done
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.done
                          ? const Color(0xFF10B981)
                          : secondaryTextColor,
                      width: 1.8,
                    ),
                  ),
                  child: task.done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: task.done ? secondaryTextColor : primaryTextColor,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),

          // Inline celebratory toast if completed
          if (isTaskFullyDone) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('task_completed_inline'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Live Subtasks Checklist
  Widget _buildSubtasksChecklist(
    BuildContext context,
    TaskModel task,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color brandPrimary,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);
    final subtasks = task.subtasks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtasks Header & Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: brandPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('live_subtasks_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              if (subtasks.isNotEmpty)
                Text(
                  '${task.completedSubtasksCount}/${subtasks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: brandPrimary,
                  ),
                ),
            ],
          ),

          // Linear progress bar if subtasks exist
          if (subtasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: subtasks.isEmpty
                    ? 0
                    : task.completedSubtasksCount / subtasks.length,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white12
                    : const Color(0xFFE2E8F5),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Subtasks List
          if (subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('no_subtasks_yet'),
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subtasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subtask = subtasks[index];
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(tasksControllerProvider)
                        .toggleSubtask(task, subtask.id);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0A1238)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: subtask.done
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Subtask Checkbox
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: subtask.done
                                ? const Color(0xFF10B981)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: subtask.done
                                  ? const Color(0xFF10B981)
                                  : secondaryTextColor,
                              width: 1.6,
                            ),
                          ),
                          child: subtask.done
                              ? const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subtask.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: subtask.done
                                  ? secondaryTextColor
                                  : primaryTextColor,
                              decoration: subtask.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 10),

          // Inline Add Subtask Field
          if (_isAddingSubtask)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtaskController,
                    autofocus: true,
                    style: TextStyle(fontSize: 13, color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: context.tr('focus_add_subtask_hint'),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: brandPrimary),
                      ),
                    ),
                    onSubmitted: (val) async {
                      if (val.trim().isNotEmpty) {
                        await ref
                            .read(tasksControllerProvider)
                            .addSubtask(task, val.trim());
                        _newSubtaskController.clear();
                        setState(() => _isAddingSubtask = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF10B981),
                  ),
                  onPressed: () async {
                    final val = _newSubtaskController.text.trim();
                    if (val.isNotEmpty) {
                      await ref
                          .read(tasksControllerProvider)
                          .addSubtask(task, val);
                      _newSubtaskController.clear();
                      setState(() => _isAddingSubtask = false);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                  onPressed: () {
                    _newSubtaskController.clear();
                    setState(() => _isAddingSubtask = false);
                  },
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => _isAddingSubtask = true),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                context.tr('focus_add_subtask_btn'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandPrimary,
                side: BorderSide(color: brandPrimary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
