import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/category_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../providers/time_audit_provider.dart';

/// Always-visible inline quick time-logging bar.
class QuickLogBar extends ConsumerStatefulWidget {
  const QuickLogBar({super.key});

  @override
  ConsumerState<QuickLogBar> createState() => _QuickLogBarState();
}

class _QuickLogBarState extends ConsumerState<QuickLogBar> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hoursController = TextEditingController(
    text: '1',
  );
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategoryId = 'work';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _hoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleLogTime() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    if (hours <= 0) return;

    setState(() {
      _isSubmitting = true;
    });

    final description = _descriptionController.text.trim().isEmpty
        ? context.tr('manual_activity_default')
        : _descriptionController.text.trim();

    final result = await ref
        .read(timeAuditServiceProvider)
        .addLog(
          uid: uid,
          category: _selectedCategoryId,
          hours: hours,
          description: description,
          date: DateTime.now(),
        );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (result != null) {
        HapticFeedback.mediumImpact();
        // Reset inputs back to defaults
        _hoursController.text = '1';
        _descriptionController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('time_logged_toast')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? TaskCategory.defaultCategories;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Category label
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF2E6FF2),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('quick_log_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  final catName = cat.isDefault
                      ? context.tr(cat.nameKey)
                      : cat.nameKey;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategoryId = cat.id;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat.color.withValues(
                                  alpha: isDark ? 0.25 : 0.15,
                                )
                              : inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? cat.color : borderColor,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cat.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? cat.color
                                    : primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Inline Inputs: Hours + Description + Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hours Input Field
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _hoursController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('hours_label'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      suffixText: 'h',
                      suffixStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E6FF2),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return context.tr('hours_invalid_error');
                      }
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return context.tr('hours_invalid_error');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Description Input Field
                Expanded(
                  child: TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('description_hint'),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: inputBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E6FF2),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _handleLogTime(),
                  ),
                ),
                const SizedBox(width: 8),

                // Log Time Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleLogTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6FF2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('log_time_btn'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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
    );
  }
}
