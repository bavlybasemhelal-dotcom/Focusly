import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/book_model.dart';
import 'book_cover_widget.dart';
import 'book_form_modal.dart';
import 'quick_update_dialog.dart';

/// Card widget representing an individual book in a shelf.
class BookCard extends StatelessWidget {
  final BookModel book;

  const BookCard({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    // Status badge text & color
    Color statusColor;
    String statusKey;
    switch (book.status) {
      case 'reading':
        statusColor = const Color(0xFF2E6FF2);
        statusKey = 'status_reading';
        break;
      case 'paused':
        statusColor = const Color(0xFFF59E0B);
        statusKey = 'status_paused';
        break;
      case 'wishlist':
        statusColor = const Color(0xFF8B5CF6);
        statusKey = 'status_wishlist';
        break;
      case 'done':
        statusColor = const Color(0xFF10B981);
        statusKey = 'status_done';
        break;
      default:
        statusColor = const Color(0xFF2E6FF2);
        statusKey = 'status_reading';
    }

    final percent = book.progressPercent;

    return Container(
      width: 155,
      margin: const EdgeInsetsDirectional.only(end: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          BookFormModal.show(context, bookToEdit: book);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover Area with Status Badge + Quick Update Action
              Stack(
                children: [
                  Center(
                    child: BookCoverWidget(
                      book: book,
                      width: 130,
                      height: 175,
                      borderRadius: 12,
                    ),
                  ),

                  // Status Badge in top-left
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F1B4C).withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        context.tr(statusKey),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),

                  // Quick Update (+) Button for non-wishlist books
                  if (!book.isWishlist)
                    PositionedDirectional(
                      bottom: 6,
                      end: 6,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          QuickUpdateDialog.show(context, book);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2E6FF2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E6FF2).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Book Title
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),

              // 3. Author Name
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),

              // 4. Progress or Rating or Wishlist indicator
              if (!book.isWishlist) ...[
                // Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100.0,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      book.isFinished
                          ? const Color(0xFF10B981)
                          : const Color(0xFF2E6FF2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Pages Progress Text
                Text(
                  context.tr(
                    'pages_progress_text',
                    args: {
                      'current': book.currentPage.toString(),
                      'total': book.totalPages.toString(),
                      'percent': percent.toString(),
                    },
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (book.isFinished && (book.rating ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: List.generate(book.rating ?? 0, (_) {
                    return const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: Color(0xFFF59E0B),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
