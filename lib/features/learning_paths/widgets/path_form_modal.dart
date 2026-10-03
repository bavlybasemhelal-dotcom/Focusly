import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/learning_path_helpers.dart';
import '../models/learning_path_model.dart';
import '../providers/learning_paths_provider.dart';

/// Modal bottom sheet for creating or editing an N-day Learning Path curriculum.
class PathFormModal extends ConsumerStatefulWidget {
  final LearningPathModel? pathToEdit;

  const PathFormModal({super.key, this.pathToEdit});

  /// Static helper to show the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    LearningPathModel? pathToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PathFormModal(pathToEdit: pathToEdit),
    );
  }

  @override
  ConsumerState<PathFormModal> createState() => _PathFormModalState();
}

class _PathFormModalState extends ConsumerState<PathFormModal> {
  late TextEditingController _titleController;
  late TextEditingController _totalDaysController;

  late int _totalDays;
  late List<PathStepModel> _steps;

  // Controllers for each day's topic title input
  final Map<int, TextEditingController> _dayControllers = {};

  String? _validationError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.pathToEdit;

    _titleController = TextEditingController(text: edit?.title ?? '');
    _totalDays = edit?.totalDays ?? 30;
    _totalDaysController = TextEditingController(text: _totalDays.toString());

    _steps = LearningPathHelpers.resizeSteps(
      edit?.steps ?? const [],
      _totalDays,
    );
    _syncDayControllers();
  }

  void _syncDayControllers() {
    for (final s in _steps) {
      if (!_dayControllers.containsKey(s.day)) {
        _dayControllers[s.day] = TextEditingController(text: s.title);
      } else {
        _dayControllers[s.day]!.text = s.title;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalDaysController.dispose();
    for (final c in _dayControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTotalDaysChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed == null || parsed <= 0 || parsed > 365) return;

    setState(() {
      _totalDays = parsed;
      // Gather current text inputs before resizing
      final currentSteps = _steps.map((s) {
        final text = _dayControllers[s.day]?.text.trim() ?? s.title;
        return s.copyWith(title: text);
      }).toList();

      _steps = LearningPathHelpers.resizeSteps(currentSteps, _totalDays);
      _syncDayControllers();
    });
  }

  Future<void> _onSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('path_title_required_validation');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _validationError = null;
      _isLoading = true;
    });

    // Extract current day titles from controllers
    final finalSteps = _steps.map((s) {
      final text = _dayControllers[s.day]?.text.trim() ?? s.title;
      return s.copyWith(title: text);
    }).toList();

    final service = ref.read(learningPathsServiceProvider);
    final edit = widget.pathToEdit;

    if (edit == null) {
      // 1. Create New Path
      final docId = await service.addPath(
        uid: uid,
        title: title,
        totalDays: _totalDays,
        initialSteps: finalSteps,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (docId != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('path_created_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      }
    } else {
      // 2. Update Existing Path
      final success = await service.updatePath(
        uid: uid,
        currentPath: edit,
        newTitle: title,
        newTotalDays: _totalDays,
        updatedSteps: finalSteps,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('path_updated_toast')),
              backgroundColor: const Color(0xFF2E6FF2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
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
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_path_confirm_title'),
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
            'delete_path_confirm_msg',
            args: {'title': widget.pathToEdit?.title ?? ''},
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && widget.pathToEdit != null) {
        final service = ref.read(learningPathsServiceProvider);
        await service.deletePath(uid: uid, pathId: widget.pathToEdit!.id);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('path_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final inputBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final isEditMode = widget.pathToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditMode
                        ? context.tr('edit_path_title')
                        : context.tr('add_path_title'),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
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
          const SizedBox(height: 16),

          // Validation Alert
          if (_validationError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Scrollable inputs area
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Path Title Field
                Text(
                  context.tr('path_title_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('path_title_hint'),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                      borderSide: const BorderSide(
                        color: Color(0xFF2E6FF2),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Total Days Input + Presets (30, 60, 90)
                Text(
                  context.tr('total_days_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _totalDaysController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                        decoration: InputDecoration(
                          suffixText: context.tr('days_unit'),
                          suffixStyle: TextStyle(color: secondaryTextColor),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
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
                            borderSide: const BorderSide(
                              color: Color(0xFF2E6FF2),
                              width: 1.8,
                            ),
                          ),
                        ),
                        onChanged: _onTotalDaysChanged,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Preset Chips
                    ...[14, 30, 60, 90].map((days) {
                      final isSelected = _totalDays == days;
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _totalDaysController.text = days.toString();
                            _onTotalDaysChanged(days.toString());
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E6FF2)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2E6FF2)
                                    : borderColor,
                              ),
                            ),
                            child: Text(
                              '$days',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Dynamic Daily Topics List
                Text(
                  context.tr('daily_topics_curriculum_header'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('daily_topics_curriculum_sub'),
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
                const SizedBox(height: 10),

                ...List.generate(_steps.length, (index) {
                  final step = _steps[index];
                  final controller = _dayControllers[step.day];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E6FF2,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${context.tr('day_label')} ${step.day}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E6FF2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryTextColor,
                            ),
                            decoration: InputDecoration(
                              hintText: context.tr('day_topic_hint'),
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Action Buttons
          const SizedBox(height: 12),
          Row(
            children: [
              if (isEditMode) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                    onPressed: _isLoading ? null : _confirmDelete,
                    tooltip: context.tr('delete'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2E6FF2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditMode
                              ? context.tr('save_changes')
                              : context.tr('save'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
