import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/decision_model.dart';
import '../providers/decision_journal_provider.dart';

/// Modal sheet for adding a new decision log or editing/reviewing an existing one.
class DecisionFormModal extends ConsumerStatefulWidget {
  final DecisionModel? decisionToEdit;
  final bool focusOutcome;

  const DecisionFormModal({
    super.key,
    this.decisionToEdit,
    this.focusOutcome = false,
  });

  /// Helper static method to open this bottom sheet modal.
  static Future<void> show(
    BuildContext context, {
    DecisionModel? decisionToEdit,
    bool focusOutcome = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DecisionFormModal(
        decisionToEdit: decisionToEdit,
        focusOutcome: focusOutcome,
      ),
    );
  }

  @override
  ConsumerState<DecisionFormModal> createState() => _DecisionFormModalState();
}

class _DecisionFormModalState extends ConsumerState<DecisionFormModal> {
  late TextEditingController _titleController;
  late TextEditingController _rationaleController;
  late TextEditingController _expectedController;
  late TextEditingController _outcomeController;

  late FocusNode _outcomeFocusNode;

  late DateTime _selectedDate;
  late bool _reviewed;
  String? _validationError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.decisionToEdit;

    _titleController = TextEditingController(text: edit?.title ?? '');
    _rationaleController = TextEditingController(text: edit?.rationale ?? '');
    _expectedController = TextEditingController(text: edit?.expected ?? '');
    _outcomeController = TextEditingController(text: edit?.outcome ?? '');

    _outcomeFocusNode = FocusNode();

    _selectedDate = edit?.date ?? DateTime.now();
    _reviewed = edit?.reviewed ?? false;

    if (widget.focusOutcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _outcomeFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rationaleController.dispose();
    _expectedController.dispose();
    _outcomeController.dispose();
    _outcomeFocusNode.dispose();
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
    final title = _titleController.text.trim();
    final rationale = _rationaleController.text.trim();
    final expected = _expectedController.text.trim();
    final outcome = _outcomeController.text.trim();

    // Validation: Title, Rationale, and Expected Outcome are all required
    if (title.isEmpty || rationale.isEmpty || expected.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('decision_required_validation');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _validationError = null;
      _isLoading = true;
    });

    final service = ref.read(decisionJournalServiceProvider);

    // Auto-mark as reviewed if outcome has text and user hasn't explicitly toggled, or follow checkbox
    final isReviewed = _reviewed || outcome.isNotEmpty;

    if (widget.decisionToEdit == null) {
      // Create new decision
      final docId = await service.addDecision(
        uid: uid,
        title: title,
        date: _selectedDate,
        rationale: rationale,
        expected: expected,
        outcome: outcome,
        reviewed: isReviewed,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (docId != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('decision_saved_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } else {
      // Update existing decision
      final updatedDecision = widget.decisionToEdit!.copyWith(
        title: title,
        date: _selectedDate,
        rationale: rationale,
        expected: expected,
        outcome: outcome,
        reviewed: isReviewed,
      );

      final success = await service.updateDecision(
        uid: uid,
        decision: updatedDecision,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('decision_updated_toast')),
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
                dialogCtx.tr('delete_decision_confirm_title'),
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
            'delete_decision_confirm_msg',
            args: {'title': widget.decisionToEdit?.title ?? ''},
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

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && widget.decisionToEdit != null) {
        final service = ref.read(decisionJournalServiceProvider);
        await service.deleteDecision(
          uid: uid,
          decisionId: widget.decisionToEdit!.id,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('decision_deleted_toast')),
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
    final isEditMode = widget.decisionToEdit != null;

    final loc = AppLocalizations.of(context);
    final dateStr = loc.formatLocalizedDate(_selectedDate);

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

            // Modal Header Title & Close Button
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
                        Icons.balance_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditMode
                          ? context.tr('edit_decision_title')
                          : context.tr('add_decision_title'),
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

            // Inline Validation Error Alert (if triggered)
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

            // 1. Decision Title Field
            Text(
              context.tr('decision_title_label'),
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
                hintText: context.tr('decision_title_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ),
            ),
            const SizedBox(height: 14),

            // 2. Decision Date Picker Row
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

            // 3. Rationale Field (Multiline)
            Text(
              context.tr('rationale_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rationaleController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('rationale_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ),
            ),
            const SizedBox(height: 14),

            // 4. Expected Outcome Field (Multiline)
            Text(
              context.tr('expected_outcome_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _expectedController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('expected_outcome_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ),
            ),
            const SizedBox(height: 14),

            // 5. Actual Outcome Field (Multiline, optional, distinct accent)
            Row(
              children: [
                Text(
                  context.tr('actual_outcome_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Optional / Review',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _outcomeController,
              focusNode: _outcomeFocusNode,
              maxLines: 3,
              onChanged: (text) {
                if (text.trim().isNotEmpty && !_reviewed) {
                  setState(() => _reviewed = true);
                }
              },
              style: TextStyle(
                fontSize: 14,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('actual_outcome_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F1B4C)
                    : const Color(0xFFF0FDF4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 6. Mark as Reviewed Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('mark_as_reviewed'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          context.tr('mark_as_reviewed_desc'),
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _reviewed,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _reviewed = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 7. Action Buttons (Save + Delete in Edit Mode)
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
