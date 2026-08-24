import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/book_model.dart';
import '../providers/reading_provider.dart';

/// Lightweight quick progress update dialog for updating a book's current page.
class QuickUpdateDialog extends ConsumerStatefulWidget {
  final BookModel book;

  const QuickUpdateDialog({
    super.key,
    required this.book,
  });

  /// Helper static method to open the dialog.
  static Future<void> show(BuildContext context, BookModel book) {
    return showDialog(
      context: context,
      builder: (_) => QuickUpdateDialog(book: book),
    );
  }

  @override
  ConsumerState<QuickUpdateDialog> createState() => _QuickUpdateDialogState();
}

class _QuickUpdateDialogState extends ConsumerState<QuickUpdateDialog> {
  late TextEditingController _pageController;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(
      text: widget.book.currentPage.toString(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _pageController.text.trim();
    final parsed = int.tryParse(text);

    if (parsed == null ||
        parsed < widget.book.currentPage ||
        parsed > widget.book.totalPages) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = context.tr(
          'invalid_page_range',
          args: {
            'min': widget.book.currentPage.toString(),
            'max': widget.book.totalPages.toString(),
          },
        );
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final service = ref.read(readingServiceProvider);
    final wasFinishedBefore = widget.book.isFinished;
    final willBeFinished = parsed >= widget.book.totalPages;

    final success = await service.quickUpdatePageProgress(
      uid: uid,
      book: widget.book,
      newPage: parsed,
      context: context,
      ref: ref,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();

        // Celebratory toast if completed for the first time
        if (!wasFinishedBefore && willBeFinished) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'book_finished_congrats',
                  args: {'title': widget.book.title},
                ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E6FF2).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bookmark_add_rounded,
              color: Color(0xFF2E6FF2),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('quick_update_title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              'quick_update_prompt',
              args: {
                'title': widget.book.title,
                'current': widget.book.currentPage.toString(),
                'total': widget.book.totalPages.toString(),
              },
            ),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 14),

          // Number input field
          TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            decoration: InputDecoration(
              suffixText: '/ ${widget.book.totalPages} pages',
              suffixStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onSubmitted: (_) => _submit(),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.tr('cancel'),
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E6FF2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  context.tr('save'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}
