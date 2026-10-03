import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/body_metrics_helpers.dart';
import '../models/body_metric_model.dart';
import '../providers/body_metrics_provider.dart';

/// Modal bottom sheet for logging or editing a body metric entry.
class BodyMetricFormModal extends ConsumerStatefulWidget {
  final BodyMetricModel? metricToEdit;
  final DateTime? initialDate;

  const BodyMetricFormModal({super.key, this.metricToEdit, this.initialDate});

  /// Static helper to open the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    BodyMetricModel? metricToEdit,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BodyMetricFormModal(
        metricToEdit: metricToEdit,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<BodyMetricFormModal> createState() =>
      _BodyMetricFormModalState();
}

class _BodyMetricFormModalState extends ConsumerState<BodyMetricFormModal> {
  late DateTime _selectedDate;
  late TextEditingController _weightController;
  late TextEditingController _bpSystolicController;
  late TextEditingController _bpDiastolicController;
  late TextEditingController _pulseController;
  late TextEditingController _noteController;

  String? _validationError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.metricToEdit;
    _selectedDate = edit?.date ?? widget.initialDate ?? DateTime.now();
    _weightController = TextEditingController(
      text: edit != null && edit.weight != null ? edit.weight.toString() : '',
    );
    _bpSystolicController = TextEditingController(
      text: edit != null && edit.bpSystolic != null
          ? edit.bpSystolic.toString()
          : '',
    );
    _bpDiastolicController = TextEditingController(
      text: edit != null && edit.bpDiastolic != null
          ? edit.bpDiastolic.toString()
          : '',
    );
    _pulseController = TextEditingController(
      text: edit != null && edit.pulse != null ? edit.pulse.toString() : '',
    );
    _noteController = TextEditingController(text: edit?.note ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _pulseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF10B981),
                    surface: Color(0xFF0F1B4C),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF10B981),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _onSave() async {
    final weightStr = _weightController.text.trim();
    final sysStr = _bpSystolicController.text.trim();
    final diaStr = _bpDiastolicController.text.trim();
    final pulseStr = _pulseController.text.trim();
    final note = _noteController.text.trim();

    final weight = double.tryParse(weightStr);
    final systolic = int.tryParse(sysStr);
    final diastolic = int.tryParse(diaStr);
    final pulse = int.tryParse(pulseStr);

    // Paired BP logic: If only one is filled, treat both as incomplete
    final int? finalSystolic =
        (systolic != null && systolic > 0 && diastolic != null && diastolic > 0)
        ? systolic
        : null;
    final int? finalDiastolic =
        (systolic != null && systolic > 0 && diastolic != null && diastolic > 0)
        ? diastolic
        : null;

    final hasAnyData =
        (weight != null && weight > 0) ||
        (finalSystolic != null && finalDiastolic != null) ||
        (pulse != null && pulse > 0) ||
        note.isNotEmpty;

    if (!hasAnyData) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('metric_validation_empty');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _validationError = null;
      _isLoading = true;
    });

    final service = ref.read(bodyMetricsServiceProvider);
    final isEdit = widget.metricToEdit != null;

    if (isEdit) {
      final success = await service.updateMetric(
        uid: uid,
        currentMetric: widget.metricToEdit!,
        newDate: _selectedDate,
        newWeight: weight,
        newBpSystolic: finalSystolic,
        newBpDiastolic: finalDiastolic,
        newPulse: pulse,
        newNote: note.isNotEmpty ? note : null,
      );

      if (mounted) {
        if (success) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('metric_saved_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          setState(() => _isLoading = false);
        }
      }
    } else {
      final docId = await service.addMetric(
        uid: uid,
        date: _selectedDate,
        weight: weight,
        bpSystolic: finalSystolic,
        bpDiastolic: finalDiastolic,
        pulse: pulse,
        note: note.isNotEmpty ? note : null,
      );

      if (mounted) {
        if (docId != null) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('metric_saved_toast')),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _onDelete() async {
    final metric = widget.metricToEdit;
    if (metric == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          dialogCtx.tr('metric_delete_confirm_title'),
          style: TextStyle(
            color: AppColors.textPrimary(dialogCtx),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          dialogCtx.tr('metric_delete_confirm_msg'),
          style: TextStyle(
            color: AppColors.textSecondary(dialogCtx),
            fontSize: 14,
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete_workout_confirm_title')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      setState(() => _isLoading = true);

      final success = await ref
          .read(bodyMetricsServiceProvider)
          .deleteMetric(uid: uid, metricId: metric.id);

      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('metric_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
    final isEdit = widget.metricToEdit != null;
    final modalBg = isDark ? const Color(0xFF08123A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandAccent = isDark
        ? AppColors.cyanElectric
        : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF10B981,
                        ).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.monitor_weight_outlined,
                          size: 20,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit
                          ? context.tr('edit_metric_modal_title')
                          : context.tr('add_metric_modal_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
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

            // Validation Error Alert if any
            if (_validationError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 1. DATE PICKER FIELD
            Text(
              context.tr('workout_date_label'),
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
                      size: 18,
                      color: brandAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      BodyMetricsHelpers.formatDateKey(_selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. WEIGHT FIELD
            Text(
              context.tr('weight_input_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(fontSize: 14, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: context.tr('weight_input_hint'),
                prefixIcon: const Icon(
                  Icons.scale_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                suffixText: context.tr('kg_unit'),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.all(12),
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
                    color: Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. BLOOD PRESSURE (SYSTOLIC & DIASTOLIC SIDE-BY-SIDE)
            Text(
              context.tr('bp_input_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Systolic
                Expanded(
                  child: TextField(
                    controller: _bpSystolicController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: context.tr('bp_systolic_hint'),
                      prefixIcon: const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.all(12),
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
                          color: Color(0xFFEF4444),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Diastolic
                Expanded(
                  child: TextField(
                    controller: _bpDiastolicController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: context.tr('bp_diastolic_hint'),
                      prefixIcon: const Icon(
                        Icons.favorite_border_rounded,
                        size: 18,
                        color: Color(0xFFF43F5E),
                      ),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.all(12),
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
                          color: Color(0xFFF43F5E),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. PULSE FIELD
            Text(
              context.tr('pulse_input_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: context.tr('pulse_input_hint'),
                prefixIcon: const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFF0EA5E9),
                ),
                suffixText: context.tr('bpm_unit'),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.all(12),
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
                    color: Color(0xFF0EA5E9),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. NOTE FIELD (Multiline)
            Text(
              context.tr('metric_note_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: context.tr('metric_note_hint'),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.all(12),
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
                    color: Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 6. ACTION BUTTONS
            Row(
              children: [
                if (isEdit) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        context.tr('delete_workout_confirm_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: _isLoading ? null : _onDelete,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
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
                            context.tr('save'),
                            style: const TextStyle(
                              fontSize: 15,
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
