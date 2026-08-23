import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/task_model.dart';
import '../services/gtd_service.dart';

/// Modal sheet for creating or editing a "Waiting For" item directly.
class AddWaitingSheet extends StatefulWidget {
  final TaskModel? taskToEdit;

  const AddWaitingSheet({super.key, this.taskToEdit});

  static Future<void> show(BuildContext context, {TaskModel? taskToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWaitingSheet(taskToEdit: taskToEdit),
    );
  }

  @override
  State<AddWaitingSheet> createState() => _AddWaitingSheetState();
}

class _AddWaitingSheetState extends State<AddWaitingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _waitingForController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _waitingForController = TextEditingController(text: widget.taskToEdit?.waitingFor ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _waitingForController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final title = _titleController.text.trim();
    final waitingFor = _waitingForController.text.trim();

    if (widget.taskToEdit != null) {
      await GTDService().updateWaitingTask(
        widget.taskToEdit!.id,
        title: title,
        waitingFor: waitingFor,
      );
    } else {
      await GTDService().createWaitingTask(title, waitingFor);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final isEditing = widget.taskToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing
                          ? context.tr('edit_waiting_title')
                          : context.tr('add_waiting_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Task title input
                Text(
                  context.tr('waiting_task_title_label'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: secondaryTextColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextFormField(
                    controller: _titleController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('field_required') : null,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: context.tr('waiting_task_title_hint'),
                      hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Waiting For person input
                Text(
                  context.tr('waiting_for_person_label'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: secondaryTextColor),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextFormField(
                    controller: _waitingForController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('field_required') : null,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: context.tr('waiting_for_person_hint'),
                      hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isEditing ? context.tr('save') : context.tr('add_waiting_btn'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
}
