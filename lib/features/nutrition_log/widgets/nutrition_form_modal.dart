import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/nutrition_log_helpers.dart';
import '../models/nutrition_log_model.dart';
import '../providers/nutrition_log_provider.dart';

/// Modal bottom sheet for logging or editing daily nutrition quality.
class NutritionFormModal extends ConsumerStatefulWidget {
  final NutritionLogModel? logToEdit;
  final DateTime? initialDate;

  const NutritionFormModal({super.key, this.logToEdit, this.initialDate});

  /// Static helper to open the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    NutritionLogModel? logToEdit,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NutritionFormModal(logToEdit: logToEdit, initialDate: initialDate),
    );
  }

  @override
  ConsumerState<NutritionFormModal> createState() => _NutritionFormModalState();
}

class _NutritionFormModalState extends ConsumerState<NutritionFormModal> {
  late int _rating;
  late DateTime _selectedDate;
  late TextEditingController _noteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.logToEdit;
    _rating = edit?.rating ?? 3; // Default rating is 3 (Average)
    _selectedDate = edit?.date ?? widget.initialDate ?? DateTime.now();
    _noteController = TextEditingController(text: edit?.note ?? '');
  }

  @override
  void dispose() {
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
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(nutritionLogServiceProvider);
      final resultId = await service.upsertNutritionLog(
        uid: uid,
        rating: _rating,
        date: _selectedDate,
        note: _noteController.text,
        existingDocId: widget.logToEdit?.id,
      );

      if (mounted) {
        if (resultId != null) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('nutrition_saved_toast')),
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _onDelete() async {
    final log = widget.logToEdit;
    if (log == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          dialogCtx.tr('nutrition_delete_confirm_title'),
          style: TextStyle(
            color: AppColors.textPrimary(dialogCtx),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          dialogCtx.tr('nutrition_delete_confirm_msg'),
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
          .read(nutritionLogServiceProvider)
          .deleteNutritionLog(uid: uid, logId: log.id);

      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('nutrition_deleted_toast')),
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
    final isEdit = widget.logToEdit != null;
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

    final ratingOptions = [
      {'val': 5, 'emoji': '😊', 'labelKey': 'nutrition_rating_5'},
      {'val': 4, 'emoji': '🙂', 'labelKey': 'nutrition_rating_4'},
      {'val': 3, 'emoji': '😐', 'labelKey': 'nutrition_rating_3'},
      {'val': 2, 'emoji': '😕', 'labelKey': 'nutrition_rating_2'},
      {'val': 1, 'emoji': '😞', 'labelKey': 'nutrition_rating_1'},
    ];

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
            // Drag handle
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

            // Header (Title + Close button)
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
                          Icons.restaurant_rounded,
                          size: 20,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit
                          ? context.tr('nutrition_modal_edit_title')
                          : context.tr('nutrition_modal_add_title'),
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
            const SizedBox(height: 18),

            // 1. DATE PICKER FIELD
            Text(
              context.tr('nutrition_date_label'),
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
                      NutritionLogHelpers.formatDateKey(_selectedDate),
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
            const SizedBox(height: 18),

            // 2. RATING SELECTOR (5 clearly-labeled options with emoji + label)
            Text(
              context.tr('nutrition_rating_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: ratingOptions.map((opt) {
                final val = opt['val'] as int;
                final emoji = opt['emoji'] as String;
                final labelKey = opt['labelKey'] as String;
                final isSelected = _rating == val;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = val);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF162B64)
                                  : const Color(0xFFECFDF5))
                            : cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? (isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF10B981))
                              : borderColor,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Emoji
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),

                          // Rating Value & Label
                          Expanded(
                            child: Text(
                              context.tr(labelKey),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? (isDark
                                          ? Colors.white
                                          : const Color(0xFF065F46))
                                    : primaryTextColor,
                              ),
                            ),
                          ),

                          // Radio Indicator
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF10B981)
                                    : secondaryTextColor.withValues(alpha: 0.4),
                                width: isSelected ? 5.5 : 1.5,
                              ),
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 3. NOTE FIELD (Multiline)
            Text(
              context.tr('nutrition_note_label'),
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
                hintText: context.tr('nutrition_note_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                  fontSize: 13,
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
                    color: Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 4. ACTION BUTTONS: SAVE & (OPTIONAL) DELETE
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
                        context.tr('delete_workout_confirm_title'), // or Delete
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
