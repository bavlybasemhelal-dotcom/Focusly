import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/book_model.dart';
import 'providers/reading_provider.dart';
import 'widgets/book_card.dart';
import 'widgets/book_form_modal.dart';
import 'widgets/reading_stats_header.dart';

/// Main Reading Tracker screen organizing books across 3 shelves:
/// Reading, Wishlist, and Finished.
class BooksShelvesPage extends ConsumerWidget {
  const BooksShelvesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final booksAsync = ref.watch(booksStreamProvider);
    final readingBooks = ref.watch(readingShelfBooksProvider);
    final wishlistBooks = ref.watch(wishlistShelfBooksProvider);
    final finishedBooks = ref.watch(finishedShelfBooksProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('reading_tracker_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('reading_tracker_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('add_book_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              BookFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.tr('add_book_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          BookFormModal.show(context);
        },
      ),
      body: booksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E6FF2)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (_) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Reading Stats Header
              const ReadingStatsHeader(),
              const SizedBox(height: 24),

              // 2. Shelf 1: Reading (includes paused)
              _buildShelfSection(
                context: context,
                title: context.tr('shelf_reading'),
                icon: Icons.auto_stories_rounded,
                iconColor: const Color(0xFF2E6FF2),
                books: readingBooks,
                emptyMessage: context.tr('empty_shelf_reading'),
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // 3. Shelf 2: Wishlist
              _buildShelfSection(
                context: context,
                title: context.tr('shelf_wishlist'),
                icon: Icons.lightbulb_outline_rounded,
                iconColor: const Color(0xFF8B5CF6),
                books: wishlistBooks,
                emptyMessage: context.tr('empty_shelf_wishlist'),
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // 4. Shelf 3: Finished
              _buildShelfSection(
                context: context,
                title: context.tr('shelf_finished'),
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                books: finishedBooks,
                emptyMessage: context.tr('empty_shelf_finished'),
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds a horizontal shelf section for a specific book category.
  Widget _buildShelfSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<BookModel> books,
    required String emptyMessage,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shelf Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${books.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Shelf Content (Horizontal List of Cards or Empty Inset Panel)
        if (books.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 24,
                  color: secondaryTextColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: books.length,
              itemBuilder: (context, index) {
                return BookCard(book: books[index]);
              },
            ),
          ),
      ],
    );
  }
}
