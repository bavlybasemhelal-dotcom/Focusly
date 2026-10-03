import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import '../models/bucket_item_model.dart';
import '../providers/bucket_list_provider.dart';

/// Bottom sheet modal for creating and updating Bucket List items
class BucketItemFormModal extends ConsumerStatefulWidget {
  final BucketItemModel? itemToEdit;

  const BucketItemFormModal({super.key, this.itemToEdit});

  static Future<void> show(
    BuildContext context, {
    BucketItemModel? itemToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BucketItemFormModal(itemToEdit: itemToEdit),
    );
  }

  @override
  ConsumerState<BucketItemFormModal> createState() =>
      _BucketItemFormModalState();
}

class _BucketItemFormModalState extends ConsumerState<BucketItemFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _memoryController;
  DateTime? _selectedTargetDate;
  late String _status; // 'pending' | 'completed'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.itemToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _memoryController = TextEditingController(text: edit?.memory ?? '');
    _selectedTargetDate = edit?.targetDate;
    _status = edit?.status ?? 'pending';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoryController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final initial = _selectedTargetDate ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
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
        _selectedTargetDate = picked;
      });
    }
  }

  Future<void> _saveItem() async {
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

    final service = ref.read(bucketListServiceProvider);
    final title = _titleController.text.trim();
    final memory = _memoryController.text.trim().isNotEmpty
        ? _memoryController.text.trim()
        : null;

    final isEdit = widget.itemToEdit != null;

    if (isEdit) {
      final updated = widget.itemToEdit!.copyWith(
        title: title,
        targetDate: _selectedTargetDate,
        status: _status,
        memory: memory,
        updatedAt: DateTime.now(),
      );
      await service.updateBucketItem(uid, updated);
    } else {
      final newItem = BucketItemModel(
        id: '',
        title: title,
        targetDate: _selectedTargetDate,
        status: _status,
        memory: memory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await service.addBucketItem(uid, newItem);
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteItem() async {
    final edit = widget.itemToEdit;
    if (edit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_item_dialog_title')),
        content: Text(context.tr('delete_item_dialog_msg')),
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
            child: Text(context.tr('delete_item_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref
            .read(bucketListServiceProvider)
            .deleteBucketItem(uid, edit.id);
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
    final isEdit = widget.itemToEdit != null;
    final isCompleted = _status == 'completed';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formattedTargetDate = _selectedTargetDate != null
        ? '${months[_selectedTargetDate!.month - 1]} ${_selectedTargetDate!.day}, ${_selectedTargetDate!.year}'
        : null;

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
                          Text(
                            isCompleted ? '🏆' : '📌',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr(
                              isEdit
                                  ? 'edit_bucket_item_title'
                                  : 'add_bucket_item_title',
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
                        context.tr('item_title_label'),
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
                          hintText: context.tr('item_title_hint'),
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('item_title_required');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Target Date Picker Tile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('item_target_date_label'),
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
                          onTap: _pickTargetDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 20,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    formattedTargetDate ??
                                        context.tr('item_target_date_label'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: formattedTargetDate != null
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: formattedTargetDate != null
                                          ? primaryTextColor
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ),
                                if (_selectedTargetDate != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedTargetDate = null;
                                      });
                                    },
                                    color: secondaryTextColor,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status Dropdown Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('item_status_label'),
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
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : borderColor,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            isExpanded: true,
                            dropdownColor: inputBg,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            items: [
                              DropdownMenuItem(
                                value: 'pending',
                                child: Row(
                                  children: [
                                    const Text(
                                      '📌',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.tr('status_pending'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'completed',
                                child: Row(
                                  children: [
                                    const Text(
                                      '🏆',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.tr('status_completed'),
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (newStatus) {
                              if (newStatus != null) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _status = newStatus;
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

                // Memory & Reflection (Prominent when status is completed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('✍️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('item_memory_label'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : primaryTextColor,
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Achieved',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _memoryController,
                        maxLines: 4,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: context.tr('item_memory_hint'),
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: isCompleted
                              ? const Color(
                                  0xFF10B981,
                                ).withValues(alpha: isDark ? 0.08 : 0.04)
                              : inputBg,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isCompleted
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.4)
                                  : borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isCompleted
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.4)
                                  : borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6366F1),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save and Delete Action Buttons
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
                        onPressed: _isSaving ? null : _saveItem,
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
                                context.tr('save_item_btn'),
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
                            context.tr('delete_item_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isSaving ? null : _deleteItem,
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
