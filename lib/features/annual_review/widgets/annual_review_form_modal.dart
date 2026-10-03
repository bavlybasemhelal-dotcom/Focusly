import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import '../models/annual_review_model.dart';
import '../providers/annual_review_provider.dart';

/// Bottom sheet modal for creating and editing yearly Annual Reviews
class AnnualReviewFormModal extends ConsumerStatefulWidget {
  final AnnualReviewModel? reviewToEdit;

  const AnnualReviewFormModal({super.key, this.reviewToEdit});

  static Future<void> show(
    BuildContext context, {
    AnnualReviewModel? reviewToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnualReviewFormModal(reviewToEdit: reviewToEdit),
    );
  }

  @override
  ConsumerState<AnnualReviewFormModal> createState() =>
      _AnnualReviewFormModalState();
}

class _AnnualReviewFormModalState extends ConsumerState<AnnualReviewFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _yearController;
  late TextEditingController _q1Controller;
  late TextEditingController _q2Controller;
  late TextEditingController _q3Controller;
  late TextEditingController _q4Controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.reviewToEdit;
    _yearController = TextEditingController(
      text: (edit?.year ?? DateTime.now().year).toString(),
    );
    _q1Controller = TextEditingController(text: edit?.q1 ?? '');
    _q2Controller = TextEditingController(text: edit?.q2 ?? '');
    _q3Controller = TextEditingController(text: edit?.q3 ?? '');
    _q4Controller = TextEditingController(text: edit?.q4 ?? '');
  }

  @override
  void dispose() {
    _yearController.dispose();
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    _q4Controller.dispose();
    super.dispose();
  }

  Future<void> _saveReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final uid = ref.read(currentUserIdProvider);
    if (uid == null || uid.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final service = ref.read(annualReviewServiceProvider);
    final year =
        int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    final q1 = _q1Controller.text.trim();
    final q2 = _q2Controller.text.trim();
    final q3 = _q3Controller.text.trim();
    final q4 = _q4Controller.text.trim();

    final isEdit = widget.reviewToEdit != null;

    if (isEdit) {
      final updated = widget.reviewToEdit!.copyWith(
        year: year,
        q1: q1,
        q2: q2,
        q3: q3,
        q4: q4,
        updatedAt: DateTime.now(),
      );
      await service.updateReview(uid, updated);
    } else {
      final newReview = AnnualReviewModel(
        id: '',
        year: year,
        q1: q1,
        q2: q2,
        q3: q3,
        q4: q4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await service.addReview(uid, newReview);
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteReview() async {
    final edit = widget.reviewToEdit;
    if (edit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_review_dialog_title')),
        content: Text(
          context.tr(
            'delete_review_dialog_msg',
            args: {'year': edit.year.toString()},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('delete_review_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(annualReviewServiceProvider).deleteReview(uid, edit.id);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final modalBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final isEdit = widget.reviewToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🗓️', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(
                            context.tr(
                              isEdit
                                  ? 'edit_annual_review_title'
                                  : 'add_annual_review_title',
                            ),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: secondaryTextColor,
                      ),
                    ],
                  ),
                ),

                // Year Input Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('review_year_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 2026',
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: Color(0xFF6366F1),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.8,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || int.tryParse(v.trim()) == null) {
                            return 'Valid year required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Question 1: Biggest Achievement (🏆)
                _buildQuestionField(
                  context: context,
                  icon: '🏆',
                  titleKey: 'review_q1_title',
                  promptKey: 'review_q1_prompt',
                  controller: _q1Controller,
                  inputBg: inputBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 16),

                // Question 2: Biggest Obstacle & How Handled (🚧)
                _buildQuestionField(
                  context: context,
                  icon: '🚧',
                  titleKey: 'review_q2_title',
                  promptKey: 'review_q2_prompt',
                  controller: _q2Controller,
                  inputBg: inputBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 16),

                // Question 3: Top Lessons Learned (🧠)
                _buildQuestionField(
                  context: context,
                  icon: '🧠',
                  titleKey: 'review_q3_title',
                  promptKey: 'review_q3_prompt',
                  controller: _q3Controller,
                  inputBg: inputBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 16),

                // Question 4: Plan & Vision for Next Year (🚀)
                _buildQuestionField(
                  context: context,
                  icon: '🚀',
                  titleKey: 'review_q4_title',
                  promptKey: 'review_q4_prompt',
                  controller: _q4Controller,
                  inputBg: inputBg,
                  borderColor: borderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                const SizedBox(height: 24),

                // Save & Delete Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isSaving ? null : _saveReview,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                context.tr('save_review_btn'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            context.tr('delete_review_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _deleteReview,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionField({
    required BuildContext context,
    required String icon,
    required String titleKey,
    required String promptKey,
    required TextEditingController controller,
    required Color inputBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                context.tr(titleKey),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 13.5,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: context.tr(promptKey),
              hintStyle: TextStyle(color: secondaryTextColor, fontSize: 12.5),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 1.8,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.tr('review_validation_all_required');
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
