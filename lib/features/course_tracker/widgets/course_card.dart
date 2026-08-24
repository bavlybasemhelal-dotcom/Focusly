import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/course_model.dart';
import '../providers/course_tracker_provider.dart';
import 'course_form_modal.dart';

/// Card rendering a single online course with progress bar and quick +/- lesson stepper.
class CourseCard extends ConsumerWidget {
  final CourseModel course;

  const CourseCard({
    super.key,
    required this.course,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981); // Emerald
      case 'paused':
        return const Color(0xFF64748B); // Slate
      case 'active':
      default:
        return const Color(0xFF0EA5E9); // Sky Blue
    }
  }

  String _getStatusLabelKey(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'course_status_completed';
      case 'paused':
        return 'course_status_paused';
      case 'active':
      default:
        return 'course_status_active';
    }
  }

  Future<void> _adjustStepper(BuildContext context, WidgetRef ref, int delta) async {
    HapticFeedback.selectionClick();
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final service = ref.read(courseTrackerServiceProvider);
    await service.adjustLessonsStepper(
      uid: uid,
      course: course,
      delta: delta,
      context: context,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_course_confirm_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          dialogCtx.tr(
            'delete_course_confirm_msg',
            args: {'title': course.title},
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        final service = ref.read(courseTrackerServiceProvider);
        await service.deleteCourse(uid: uid, courseId: course.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('course_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final stepperBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9);

    final statusColor = _getStatusColor(course.status);
    final statusLabelKey = _getStatusLabelKey(course.status);
    final pct = course.progressPercent;
    final isDone = course.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : borderColor,
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Left Accent Spine
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: statusColor),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: Status Badge + Platform Tag + Certificate Tag + Action Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr(statusLabelKey),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Platform Tag
                      if (course.platform != null && course.platform!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            course.platform!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: secondaryTextColor,
                        tooltip: context.tr('edit_course_title'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          CourseFormModal.show(context, courseToEdit: course);
                        },
                      ),
                      const SizedBox(width: 4),

                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: const Color(0xFFEF4444),
                        tooltip: context.tr('delete'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Course Title
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Certificate Badge
                  if (course.certificate) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B), // Amber
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('certificate_earned_badge'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Optional Note
                  if (course.note != null && course.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      course.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Progress Bar & Stats
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom Row: Progress Text + Stepper Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr(
                          'course_lessons_progress',
                          args: {
                            'completed': course.completedLessons.toString(),
                            'total': course.totalLessons.toString(),
                            'percent': pct.toString(),
                          },
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDone ? const Color(0xFF10B981) : secondaryTextColor,
                        ),
                      ),

                      // Stepper Pair: [-] and [+]
                      Container(
                        decoration: BoxDecoration(
                          color: stepperBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: course.completedLessons > 0
                                  ? () => _adjustStepper(context, ref, -1)
                                  : null,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: course.completedLessons > 0
                                      ? primaryTextColor
                                      : secondaryTextColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: borderColor,
                            ),
                            InkWell(
                              onTap: course.completedLessons < course.totalLessons
                                  ? () => _adjustStepper(context, ref, 1)
                                  : null,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: course.completedLessons < course.totalLessons
                                      ? const Color(0xFF0EA5E9)
                                      : secondaryTextColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
