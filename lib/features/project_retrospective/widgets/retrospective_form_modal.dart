import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../para/models/para_project_model.dart';
import '../../para/providers/para_provider.dart';
import '../models/retrospective_model.dart';
import '../providers/retrospective_provider.dart';

/// Bottom modal sheet for creating and editing Project Retrospectives.
class RetrospectiveFormModal extends ConsumerStatefulWidget {
  final RetrospectiveModel? retrospectiveToEdit;

  const RetrospectiveFormModal({
    super.key,
    this.retrospectiveToEdit,
  });

  /// Helper static method to show the retrospective modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    RetrospectiveModel? retrospectiveToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RetrospectiveFormModal(
        retrospectiveToEdit: retrospectiveToEdit,
      ),
    );
  }

  @override
  ConsumerState<RetrospectiveFormModal> createState() =>
      _RetrospectiveFormModalState();
}

class _RetrospectiveFormModalState
    extends ConsumerState<RetrospectiveFormModal> {
  String? _selectedProjectId;
  late DateTime _selectedDate;

  late TextEditingController _wentWellController;
  late TextEditingController _toImproveController;
  late TextEditingController _learningsController;

  String? _validationError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.retrospectiveToEdit;

    _selectedProjectId = edit?.projectId;
    _selectedDate = edit?.date ?? DateTime.now();

    _wentWellController = TextEditingController(text: edit?.wentWell ?? '');
    _toImproveController = TextEditingController(text: edit?.toImprove ?? '');
    _learningsController = TextEditingController(text: edit?.learnings ?? '');
  }

  @override
  void dispose() {
    _wentWellController.dispose();
    _toImproveController.dispose();
    _learningsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF2E6FF2),
                    surface: Color(0xFF0F1B4C),
                    onSurface: Colors.white,
                  ),
                  dialogTheme: DialogThemeData(
                    backgroundColor: const Color(0xFF0F1B4C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF2E6FF2),
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                  dialogTheme: DialogThemeData(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _onSave() async {
    final wentWell = _wentWellController.text.trim();
    final toImprove = _toImproveController.text.trim();
    final learnings = _learningsController.text.trim();

    // 1. Validate project selection
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('project_required_validation');
      });
      return;
    }

    // 2. Validate all 3 review reflection fields
    if (wentWell.isEmpty || toImprove.isEmpty || learnings.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('all_retro_fields_required');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _validationError = null;
      _isLoading = true;
    });

    final service = ref.read(retrospectiveServiceProvider);

    if (widget.retrospectiveToEdit == null) {
      // Create new retrospective
      final docId = await service.addRetrospective(
        uid: uid,
        projectId: _selectedProjectId!,
        date: _selectedDate,
        wentWell: wentWell,
        toImprove: toImprove,
        learnings: learnings,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (docId != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('retrospective_saved_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } else {
      // Update existing retrospective
      final updated = widget.retrospectiveToEdit!.copyWith(
        projectId: _selectedProjectId,
        date: _selectedDate,
        wentWell: wentWell,
        toImprove: toImprove,
        learnings: learnings,
      );

      final success = await service.updateRetrospective(
        uid: uid,
        retrospective: updated,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('retrospective_updated_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_retrospective_confirm_title'),
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
          dialogCtx.tr('delete_retrospective_confirm_msg'),
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

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && widget.retrospectiveToEdit != null) {
        final service = ref.read(retrospectiveServiceProvider);
        await service.deleteRetrospective(
          uid: uid,
          retrospectiveId: widget.retrospectiveToEdit!.id,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('retrospective_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final isEditMode = widget.retrospectiveToEdit != null;

    final loc = AppLocalizations.of(context);
    final dateStr = loc.formatLocalizedDate(_selectedDate);

    // Watch PARA Projects for dropdown
    final allProjectsAsync = ref.watch(allParaProjectsStreamProvider);
    final projectsList = allProjectsAsync.value ?? <ParaProjectModel>[];

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
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

            // Header Title
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
                        Icons.find_in_page_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditMode
                          ? context.tr('edit_retrospective_title')
                          : context.tr('add_retrospective_title'),
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
            const SizedBox(height: 18),

            // Validation Error Alert
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
              const SizedBox(height: 14),
            ],

            // 1. Project Dropdown
            Text(
              context.tr('select_project_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (projectsList.any((p) => p.id == _selectedProjectId))
                      ? _selectedProjectId
                      : null,
                  hint: Text(
                    context.tr('select_project_placeholder'),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: secondaryTextColor,
                  ),
                  items: [
                    ...projectsList.map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_special_rounded,
                              size: 18,
                              color: Color(0xFF2E6FF2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.archived)
                              Container(
                                margin: const EdgeInsetsDirectional.only(start: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Archived',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedProjectId = val;
                    });
                  },
                ),
              ),
            ),
            if (projectsList.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('no_projects_available_warning'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 2. Date Picker
            Text(
              context.tr('decision_date_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
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
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Color(0xFF2E6FF2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. What Went Well (Multiline)
            Text(
              context.tr('went_well_label'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _wentWellController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('went_well_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF0FDF4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. What Needs Improvement (Multiline)
            Text(
              context.tr('to_improve_label'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _toImproveController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('to_improve_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFFEF2F2),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Lessons Learned & Next Steps (Multiline)
            Text(
              context.tr('learnings_label'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E6FF2),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _learningsController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('learnings_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFF2E6FF2).withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFF2E6FF2).withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
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
      ),
    );
  }
}
