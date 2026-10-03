import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'areas_page.dart';
import 'archive_page.dart';
import 'projects_page.dart';
import 'resources_page.dart';

/// Interactive PARA Guide explaining the method and providing quick navigation shortcuts.
class ParaGuidePage extends StatelessWidget {
  const ParaGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final scaffoldBg = isDark
        ? const Color(0xFF070D28)
        : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('para_guide_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
        children: [
          // Hero Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr('para_method_hero_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('para_method_hero_desc'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Category Jump Cards
          Text(
            context.tr('para_pillars_title'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Projects
          _buildPillarCard(
            context: context,
            title: context.tr('para_projects_title'),
            letter: 'P',
            color: const Color(0xFF2563EB),
            icon: Icons.folder_special_rounded,
            description: context.tr('para_projects_desc'),
            actionLabel: context.tr('view_projects_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProjectsPage()),
              );
            },
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 12),

          // 2. Areas
          _buildPillarCard(
            context: context,
            title: context.tr('para_areas_title'),
            letter: 'A',
            color: const Color(0xFF10B981),
            icon: Icons.domain_rounded,
            description: context.tr('para_areas_desc'),
            actionLabel: context.tr('view_areas_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AreasPage()),
              );
            },
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 12),

          // 3. Resources
          _buildPillarCard(
            context: context,
            title: context.tr('para_resources_title'),
            letter: 'R',
            color: const Color(0xFF06B6D4),
            icon: Icons.source_rounded,
            description: context.tr('para_resources_desc'),
            actionLabel: context.tr('view_resources_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ResourcesPage()),
              );
            },
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 12),

          // 4. Archive
          _buildPillarCard(
            context: context,
            title: context.tr('para_archive_title'),
            letter: 'A',
            color: const Color(0xFF8B5CF6),
            icon: Icons.inventory_2_rounded,
            description: context.tr('para_archive_desc'),
            actionLabel: context.tr('view_archive_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ArchivePage()),
              );
            },
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard({
    required BuildContext context,
    required String title,
    required String letter,
    required Color color,
    required IconData icon,
    required String description,
    required String actionLabel,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icon, color: color, size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: secondaryTextColor.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
