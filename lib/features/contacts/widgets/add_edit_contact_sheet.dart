import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/contact_model.dart';
import '../providers/contacts_provider.dart';

/// Modal bottom sheet for creating or editing a personal contact.
class AddEditContactSheet extends ConsumerStatefulWidget {
  final ContactModel? contact;

  const AddEditContactSheet({
    super.key,
    this.contact,
  });

  static Future<void> show(BuildContext context, {ContactModel? contact}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditContactSheet(contact: contact),
    );
  }

  @override
  ConsumerState<AddEditContactSheet> createState() => _AddEditContactSheetState();
}

class _AddEditContactSheetState extends ConsumerState<AddEditContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _contactInfoController;
  late final TextEditingController _remindDaysController;
  late final TextEditingController _notesController;

  late String _selectedEmoji;
  late DateTime _selectedLastContact;
  int _remindDays = 30;
  bool _isSaving = false;

  static const List<String> _emojiPresets = [
    '🙂', '😊', '🤩', '😎', '🤝', '💼', '🎓', '❤️', '🌟', '👨‍👩‍👧', '🧑‍💻', '☕'
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?.name ?? '');
    _roleController = TextEditingController(text: c?.role ?? '');
    _contactInfoController = TextEditingController(text: c?.contactInfo ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _remindDays = c?.remindDays ?? 30;
    _remindDaysController = TextEditingController(text: '$_remindDays');

    _selectedEmoji = c?.emoji ?? '🙂';
    _selectedLastContact = c?.lastContact ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _contactInfoController.dispose();
    _remindDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.contact != null;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    final contactInfo = _contactInfoController.text.trim();
    final notes = _notesController.text.trim();
    final parsedRemindDays = int.tryParse(_remindDaysController.text.trim()) ?? _remindDays;

    bool success;
    if (_isEditMode) {
      final updated = widget.contact!.copyWith(
        name: name,
        emoji: _selectedEmoji,
        role: role.isNotEmpty ? role : null,
        clearRole: role.isEmpty,
        contactInfo: contactInfo.isNotEmpty ? contactInfo : null,
        clearContactInfo: contactInfo.isEmpty,
        lastContact: _selectedLastContact,
        remindDays: parsedRemindDays > 0 ? parsedRemindDays : 30,
        notes: notes.isNotEmpty ? notes : null,
        clearNotes: notes.isEmpty,
      );
      success = await ref.read(contactsServiceProvider).updateContact(
            uid: uid,
            contact: updated,
          );
    } else {
      final newId = await ref.read(contactsServiceProvider).addContact(
            uid: uid,
            name: name,
            emoji: _selectedEmoji,
            role: role.isNotEmpty ? role : null,
            contactInfo: contactInfo.isNotEmpty ? contactInfo : null,
            lastContact: _selectedLastContact,
            remindDays: parsedRemindDays > 0 ? parsedRemindDays : 30,
            notes: notes.isNotEmpty ? notes : null,
          );
      success = newId != null;
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? context.tr('contact_updated_toast')
                  : context.tr('contact_added_toast'),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('delete_contact_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.tr(
            'delete_contact_confirm_msg',
            args: {'name': widget.contact!.name},
          ),
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await ref.read(contactsServiceProvider).deleteContact(
              uid: uid,
              contactId: widget.contact!.id,
            );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('contact_deleted_toast')),
              backgroundColor: AppColors.errorRed,
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
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final isToday = DateUtils.isSameDay(_selectedLastContact, DateTime.now());
    final lastContactDisplay = isToday
        ? context.tr('today')
        : DateFormat.yMMMMd().format(_selectedLastContact);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode
                          ? context.tr('edit_contact_title')
                          : context.tr('add_contact_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Emoji Avatar Selector Row
                Text(
                  context.tr('contact_avatar_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _emojiPresets.map((emoji) {
                      final isSelected = _selectedEmoji == emoji;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedEmoji = emoji;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E6FF2).withValues(alpha: 0.15)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2E6FF2)
                                    : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Contact Name Field (Required)
                Text(
                  context.tr('contact_name_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: context.tr('contact_name_hint'),
                    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: inputBg,
                    prefixIcon: Icon(Icons.person_outline_rounded, color: secondaryTextColor, size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.tr('contact_name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role / Relationship Field
                Text(
                  context.tr('contact_role_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _roleController,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: context.tr('contact_role_hint'),
                    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: inputBg,
                    prefixIcon: Icon(Icons.badge_outlined, color: secondaryTextColor, size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Info Field (Phone, Email, or Handle)
                Text(
                  context.tr('contact_info_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contactInfoController,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: context.tr('contact_info_hint'),
                    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: inputBg,
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: secondaryTextColor, size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Last Contact Date Picker & "Mark as contacted today" Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('last_contact_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedLastContact = DateTime.now();
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('mark_contacted_today_btn'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedLastContact,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedLastContact = picked;
                      });
                    }
                  },
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
                        Icon(Icons.calendar_month_rounded, color: const Color(0xFF2E6FF2), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          lastContactDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Remind After (Days) Stepper Field
                Text(
                  context.tr('remind_days_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('remind_days_helper'),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final current = int.tryParse(_remindDaysController.text) ?? _remindDays;
                        if (current > 1) {
                          setState(() {
                            _remindDays = current - 1;
                            _remindDaysController.text = '$_remindDays';
                          });
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFF2E6FF2),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _remindDaysController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputBg,
                          suffixText: context.tr('days_unit'),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final current = int.tryParse(_remindDaysController.text) ?? _remindDays;
                        setState(() {
                          _remindDays = current + 1;
                          _remindDaysController.text = '$_remindDays';
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: const Color(0xFF2E6FF2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes Field
                Text(
                  context.tr('contact_notes_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: context.tr('contact_notes_hint'),
                    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: inputBg,
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
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons: Save + Delete (if edit mode)
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isEditMode
                                ? context.tr('update_contact_btn')
                                : context.tr('save_contact_btn'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),

                if (_isEditMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 18),
                      label: Text(
                        context.tr('delete_contact_btn'),
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.errorRed.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
