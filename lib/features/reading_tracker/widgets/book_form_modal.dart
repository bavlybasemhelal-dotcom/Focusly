import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/book_model.dart';
import '../providers/reading_provider.dart';

/// Preset palette colors for book covers
const List<int> _kCoverColors = [
  0xFF2E6FF2, // Electric Sapphire
  0xFF0D9488, // Deep Teal
  0xFF10B981, // Emerald Green
  0xFFF59E0B, // Amber Gold
  0xFFEF4444, // Rose Coral
  0xFF8B5CF6, // Royal Purple
  0xFFEC4899, // Vibrant Pink
  0xFF475569, // Slate Dark
];

/// Modal sheet for adding a new book or editing an existing one.
class BookFormModal extends ConsumerStatefulWidget {
  final BookModel? bookToEdit;

  const BookFormModal({super.key, this.bookToEdit});

  /// Helper static method to open the modal bottom sheet.
  static Future<void> show(BuildContext context, {BookModel? bookToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookFormModal(bookToEdit: bookToEdit),
    );
  }

  @override
  ConsumerState<BookFormModal> createState() => _BookFormModalState();
}

class _BookFormModalState extends ConsumerState<BookFormModal> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _totalPagesController;
  late TextEditingController _currentPageController;
  late TextEditingController _notesController;

  late String _status; // 'reading' | 'paused' | 'wishlist' | 'done'
  late int _coverColor;
  DateTime? _startDate;
  DateTime? _finishDate;
  int? _rating;

  String? _validationError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.bookToEdit;

    _titleController = TextEditingController(text: edit?.title ?? '');
    _authorController = TextEditingController(text: edit?.author ?? '');
    _totalPagesController = TextEditingController(
      text: (edit?.totalPages ?? 200).toString(),
    );
    _currentPageController = TextEditingController(
      text: (edit?.currentPage ?? 0).toString(),
    );
    _notesController = TextEditingController(text: edit?.notes ?? '');

    _status = edit?.status ?? 'reading';
    _coverColor = edit?.coverColor ?? _kCoverColors[0];
    _startDate =
        edit?.startDate ?? (_status != 'wishlist' ? DateTime.now() : null);
    _finishDate = edit?.finishDate;
    _rating = edit?.rating;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _totalPagesController.dispose();
    _currentPageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFinishDate}) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = (isFinishDate ? _finishDate : _startDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF2E6FF2),
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isFinishDate) {
          _finishDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _onSave() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();

    if (title.isEmpty || author.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = context.tr('book_required_validation');
      });
      return;
    }

    final totalPages = int.tryParse(_totalPagesController.text.trim()) ?? 200;
    final validTotal = totalPages > 0 ? totalPages : 200;
    final rawCurrent = int.tryParse(_currentPageController.text.trim()) ?? 0;
    final validCurrent = rawCurrent.clamp(0, validTotal);

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _validationError = null;
      _isLoading = true;
    });

    final service = ref.read(readingServiceProvider);
    final isFinishing = validCurrent >= validTotal || _status == 'done';
    final actualStatus = isFinishing ? 'done' : _status;
    final now = DateTime.now();

    if (widget.bookToEdit == null) {
      // 1. Create New Book
      final docId = await service.addBook(
        uid: uid,
        title: title,
        author: author,
        totalPages: validTotal,
        currentPage: validCurrent,
        status: actualStatus,
        coverColor: _coverColor,
        startDate: _startDate ?? (actualStatus != 'wishlist' ? now : null),
        finishDate: isFinishing ? (_finishDate ?? now) : null,
        rating: isFinishing ? (_rating ?? 5) : null,
        notes: _notesController.text.trim(),
        context: context,
        ref: ref,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (docId != null) {
          Navigator.of(context).pop();
          if (isFinishing) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('book_finished_congrats', args: {'title': title}),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('book_saved_toast')),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          }
        }
      }
    } else {
      // 2. Update Existing Book
      final oldBook = widget.bookToEdit!;
      final newBook = oldBook.copyWith(
        title: title,
        author: author,
        totalPages: validTotal,
        currentPage: validCurrent,
        status: actualStatus,
        coverColor: _coverColor,
        startDate: _startDate,
        finishDate: isFinishing ? (_finishDate ?? now) : null,
        rating: isFinishing ? (_rating ?? 5) : null,
        notes: _notesController.text.trim(),
        clearFinishDate: !isFinishing,
        clearRating: !isFinishing,
      );

      final success = await service.updateBook(
        uid: uid,
        newBook: newBook,
        oldBook: oldBook,
        context: context,
        ref: ref,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.of(context).pop();
          if (!oldBook.isFinished && isFinishing) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('book_finished_congrats', args: {'title': title}),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('book_updated_toast')),
                backgroundColor: const Color(0xFF2E6FF2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          }
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
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_book_confirm_title'),
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
            'delete_book_confirm_msg',
            args: {'title': widget.bookToEdit?.title ?? ''},
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && widget.bookToEdit != null) {
        final service = ref.read(readingServiceProvider);
        await service.deleteBook(uid: uid, bookId: widget.bookToEdit!.id);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('book_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final inputBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final isEditMode = widget.bookToEdit != null;

    final loc = AppLocalizations.of(context);

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
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditMode
                          ? context.tr('edit_book_title')
                          : context.tr('add_book_title'),
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

            // Validation Alert
            if (_validationError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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

            // 1. Title Field
            Text(
              context.tr('book_title_label'),
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
                hintText: context.tr('book_title_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                    color: Color(0xFF2E6FF2),
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Author Field
            Text(
              context.tr('author_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _authorController,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: context.tr('author_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                    color: Color(0xFF2E6FF2),
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Status Dropdown
            Text(
              context.tr('status_label'),
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
                  value: _status,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF0F1B4C)
                      : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: secondaryTextColor,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'reading',
                      child: Text(
                        context.tr('status_reading'),
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'paused',
                      child: Text(
                        context.tr('status_paused'),
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'wishlist',
                      child: Text(
                        context.tr('status_wishlist'),
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'done',
                      child: Text(
                        context.tr('status_done'),
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _status = val;

                        // =========================================================================
                        // Status -> Current Page sync:
                        // When marking a book as 'done' (Finished) via the Status dropdown,
                        // automatically snap Current Page equal to Total Pages in the form so
                        // the two fields stay consistent without requiring the user to type
                        // the total page count manually.
                        // =========================================================================
                        if (_status == 'done') {
                          final totalPages =
                              int.tryParse(_totalPagesController.text.trim()) ??
                              200;
                          final validTotal = totalPages > 0 ? totalPages : 200;
                          _currentPageController.text = validTotal.toString();
                          _finishDate ??= DateTime.now();
                        }
                        // Note: If the user changes Status AWAY from 'done' back to 'reading' or 'paused',
                        // we intentionally do NOT force Current Page down to an arbitrary value, leaving
                        // whatever progress was entered intact.
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Pages Row (Total Pages + Current Page)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('total_pages_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _totalPagesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                        onChanged: (val) {
                          // If the book is currently marked 'done' (Finished) and the total page count
                          // is modified, keep Current Page synchronized to match the new Total Pages.
                          if (_status == 'done') {
                            final total = int.tryParse(val.trim()) ?? 200;
                            if (total > 0) {
                              setState(() {
                                _currentPageController.text = total.toString();
                              });
                            }
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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
                              color: Color(0xFF2E6FF2),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('current_page_label'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _currentPageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                        onChanged: (val) {
                          final cur = int.tryParse(val.trim()) ?? 0;
                          final total =
                              int.tryParse(_totalPagesController.text.trim()) ??
                              200;
                          // =========================================================================
                          // Current Page -> Status sync:
                          // If current page reaches or exceeds total pages, auto-flip Status to 'done' (Finished).
                          // =========================================================================
                          if (total > 0 && cur >= total && _status != 'done') {
                            setState(() {
                              _status = 'done';
                              _finishDate ??= DateTime.now();
                            });
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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
                              color: Color(0xFF2E6FF2),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 5. Cover Color Swatch Picker
            Text(
              context.tr('cover_color_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kCoverColors.map((colorVal) {
                final isSelected = _coverColor == colorVal;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _coverColor = colorVal);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Color(colorVal).withValues(alpha: 0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 6. Conditional Dates & Rating based on Status
            if (_status != 'wishlist') ...[
              // Start Date
              Text(
                context.tr('start_date_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickDate(isFinishDate: false),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                          _startDate != null
                              ? loc.formatLocalizedDate(_startDate!)
                              : 'Not set',
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
            ],

            if (_status == 'done') ...[
              // Finish Date
              Text(
                context.tr('finish_date_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickDate(isFinishDate: true),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _finishDate != null
                              ? loc.formatLocalizedDate(_finishDate!)
                              : 'Today',
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

              // Rating (1-5 stars)
              Text(
                context.tr('rating_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isFilled = (_rating ?? 0) >= starNum;
                  return IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFilled
                          ? const Color(0xFFF59E0B)
                          : secondaryTextColor,
                      size: 32,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = starNum);
                    },
                  );
                }),
              ),
              const SizedBox(height: 14),
            ],

            // 7. Notes Field
            Text(
              context.tr('notes_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: context.tr('notes_hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                    color: Color(0xFF2E6FF2),
                    width: 1.8,
                  ),
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
