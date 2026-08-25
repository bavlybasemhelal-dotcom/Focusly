import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import '../models/legacy_entry_model.dart';
import '../providers/legacy_journal_provider.dart';

/// Bottom sheet modal for creating and updating Legacy Journal entries
class LegacyEntryFormModal extends ConsumerStatefulWidget {
  final LegacyEntryModel? entryToEdit;

  const LegacyEntryFormModal({
    super.key,
    this.entryToEdit,
  });

  static Future<void> show(BuildContext context, {LegacyEntryModel? entryToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegacyEntryFormModal(entryToEdit: entryToEdit),
    );
  }

  @override
  ConsumerState<LegacyEntryFormModal> createState() => _LegacyEntryFormModalState();
}

class _LegacyEntryFormModalState extends ConsumerState<LegacyEntryFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _selectedDate;
  late String _type; // 'letter' | 'value' | 'will'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.entryToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _contentController = TextEditingController(text: edit?.content ?? '');
    _selectedDate = edit?.date ?? DateTime.now();
    _type = edit?.type ?? 'letter';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0F172A),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEntry() async {
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

    final service = ref.read(legacyJournalServiceProvider);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final isEdit = widget.entryToEdit != null;

    if (isEdit) {
      final updated = widget.entryToEdit!.copyWith(
        title: title,
        date: _selectedDate,
        type: _type,
        content: content,
        updatedAt: DateTime.now(),
      );
      await service.updateEntry(uid, updated);
    } else {
      final newEntry = LegacyEntryModel(
        id: '',
        title: title,
        date: _selectedDate,
        type: _type,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await service.addEntry(uid, newEntry);
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteEntry() async {
    final edit = widget.entryToEdit;
    if (edit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_legacy_dialog_title')),
        content: Text(context.tr('delete_legacy_dialog_msg')),
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
            child: Text(context.tr('delete_legacy_entry_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(legacyJournalServiceProvider).deleteEntry(uid, edit.id);
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
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final isEdit = widget.entryToEdit != null;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDate =
        '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';

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
                          const Text('✍️', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(
                            context.tr(
                              isEdit ? 'edit_legacy_entry_title' : 'add_legacy_entry_title',
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

                // Title Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('legacy_entry_title_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: primaryTextColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.tr('legacy_entry_title_hint'),
                          hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('legacy_validation_required');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date Picker Tile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('legacy_entry_date_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 18, color: Color(0xFF6366F1)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 18, color: secondaryTextColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Type Dropdown Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('legacy_entry_type_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _type,
                            isExpanded: true,
                            dropdownColor: inputBg,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            items: [
                              DropdownMenuItem(
                                value: 'letter',
                                child: Row(
                                  children: [
                                    const Text('✉️', style: TextStyle(fontSize: 15)),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.tr('legacy_type_letter'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'value',
                                child: Row(
                                  children: [
                                    const Text('💎', style: TextStyle(fontSize: 15)),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.tr('legacy_type_value'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'will',
                                child: Row(
                                  children: [
                                    const Text('📜', style: TextStyle(fontSize: 15)),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.tr('legacy_type_will'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (newType) {
                              if (newType != null) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _type = newType;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content Editor (Multiline, ample space)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('legacy_entry_content_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentController,
                        minLines: 6,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: context.tr('legacy_entry_content_hint'),
                          hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.all(16),
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
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('legacy_validation_required');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save and Delete Buttons
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
                        onPressed: _isSaving ? null : _saveEntry,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                context.tr('save_legacy_entry_btn'),
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
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(
                            context.tr('delete_legacy_entry_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _deleteEntry,
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
}
