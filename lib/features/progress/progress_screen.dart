import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/progress_provider.dart';
import 'widgets/achievements_grid_view.dart';
import 'widgets/level_header_card.dart';
import 'widgets/productivity_overview_view.dart';

/// Main Progress & Achievements screen in Focusly.
///
/// Houses user Level progression, XP metrics, productivity analytics,
/// and the comprehensive achievement badge gallery.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedSubTab = 0; // 0 = Overview, 1 = Achievements

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final levelInfo = ref.watch(userLevelProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Aurora Background Blooms
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -----------------------------------------------------------
                  // 1. SCREEN HEADER
                  // -----------------------------------------------------------
                  Text(
                    context.tr('progress_and_achievements'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('progress_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // 2. LEVEL HEADER PROGRESSION CARD
                  // -----------------------------------------------------------
                  LevelHeaderCard(levelInfo: levelInfo),

                  const SizedBox(height: 20),

                  // -----------------------------------------------------------
                  // 3. SEGMENTED TAB SWITCHER (Overview / Achievements)
                  // -----------------------------------------------------------
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F1B4C)
                          : const Color(0xFFE2E8F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSubTabButton(
                            index: 0,
                            title: context.tr('tab_overview'),
                            icon: Icons.bar_chart_rounded,
                            isSelected: _selectedSubTab == 0,
                            brandPrimary: brandPrimary,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildSubTabButton(
                            index: 1,
                            title: context.tr('tab_achievements'),
                            icon: Icons.military_tech_rounded,
                            isSelected: _selectedSubTab == 1,
                            brandPrimary: brandPrimary,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -----------------------------------------------------------
                  // 4. SUB-TAB VIEW CONTENT
                  // -----------------------------------------------------------
                  if (_selectedSubTab == 0)
                    const ProductivityOverviewView()
                  else
                    const AchievementsGridView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color brandPrimary,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSubTab = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? brandPrimary
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8)
                  .withValues(alpha: isDark ? 0.12 : 0.14),
            ),
          ),
        ),
        Positioned(
          top: 300,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B)
                  .withValues(alpha: isDark ? 0.08 : 0.1),
            ),
          ),
        ),
      ],
    );
  }
}
