import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/achievement_model.dart';
import '../models/achievements_data.dart';
import '../providers/progress_provider.dart';
import '../services/progress_service.dart';
import 'achievement_card.dart';

/// Grid view of all achievements grouped by category with unlock progress tallies.
class AchievementsGridView extends ConsumerStatefulWidget {
  const AchievementsGridView({super.key});

  @override
  ConsumerState<AchievementsGridView> createState() =>
      _AchievementsGridViewState();
}

class _AchievementsGridViewState extends ConsumerState<AchievementsGridView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ProgressService().checkAndUnlockAchievements(
          context: context,
          widgetRef: ref,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlockedAsync = ref.watch(unlockedAchievementsStreamProvider);
    final unlockedMap = unlockedAsync.value ?? {};

    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: AchievementCategory.values.length,
      itemBuilder: (context, index) {
        final category = AchievementCategory.values[index];
        final items = AchievementsData.allAchievements
            .where((a) => a.category == category)
            .toList();

        final unlockedCount = items
            .where((a) => unlockedMap.containsKey(a.id))
            .length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(category.titleKey),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: unlockedCount == items.length
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : secondaryTextColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unlockedCount / ${items.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: unlockedCount == items.length
                            ? const Color(0xFF10B981)
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2-Column Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 155,
                ),
                itemBuilder: (context, gridIndex) {
                  final achievement = items[gridIndex];
                  final isUnlocked = unlockedMap.containsKey(achievement.id);
                  final unlockedAt = unlockedMap[achievement.id];

                  return AchievementCard(
                    achievement: achievement,
                    isUnlocked: isUnlocked,
                    unlockedAt: unlockedAt,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
