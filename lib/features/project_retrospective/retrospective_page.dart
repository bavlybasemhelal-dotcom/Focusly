import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/retrospective_model.dart';
import 'providers/retrospective_provider.dart';
import 'widgets/retrospective_card.dart';
import 'widgets/retrospective_form_modal.dart';

/// Project Retrospective list screen for post-mortem reflections on PARA projects.
class RetrospectivePage extends ConsumerWidget {
  const RetrospectivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final retrosAsync = ref.watch(retrospectivesStreamProvider);

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
              context.tr('retrospectives_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('retrospectives_subtitle'),
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
            tooltip: context.tr('new_retrospective_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              RetrospectiveFormModal.show(context);
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
          context.tr('new_retrospective_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          RetrospectiveFormModal.show(context);
        },
      ),
      body: retrosAsync.when(
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
        data: (retros) {
          if (retros.isEmpty) {
            return _buildEmptyState(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            itemCount: retros.length,
            itemBuilder: (context, index) {
              return RetrospectiveCard(retrospective: retros[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E3A8A).withValues(alpha: 0.5),
                          const Color(0xFF0F1B4C),
                        ]
                      : [
                          const Color(0xFFDBEAFE),
                          const Color(0xFFEFF6FF),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E6FF2).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.find_in_page_rounded,
                size: 40,
                color: Color(0xFF2E6FF2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('empty_retrospectives_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('empty_retrospectives_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('new_retrospective_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                RetrospectiveFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
