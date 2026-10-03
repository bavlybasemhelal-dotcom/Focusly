import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/goals_provider.dart';
import 'widgets/goal_card.dart';
import 'widgets/goal_form_modal.dart';

/// Life Map Board Screen (4 Timeframe Columns: 1 Month, 3 Months, 1 Year, 5 Years).
class LifeMapPage extends ConsumerStatefulWidget {
  const LifeMapPage({super.key});

  @override
  ConsumerState<LifeMapPage> createState() => _LifeMapPageState();
}

class _LifeMapPageState extends ConsumerState<LifeMapPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _timeframeKeys = [
    '1month',
    '3months',
    '1year',
    '5years',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _timeframeKeys.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final goalsAsync = ref.watch(goalsStreamProvider);
    final showCompleted = ref.watch(showCompletedGoalsProvider);
    final allGoals = goalsAsync.value ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('life_map_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        actions: [
          // Show / Hide Completed Goals Toggle
          IconButton(
            icon: Icon(
              showCompleted
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: showCompleted
                  ? const Color(0xFF2E6FF2)
                  : secondaryTextColor,
            ),
            tooltip: showCompleted
                ? context.tr('hide_completed_goals_btn')
                : context.tr('show_completed_goals_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(showCompletedGoalsProvider.notifier).toggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('add_goal_title'),
            onPressed: () => GoalFormModal.show(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E6FF2), Color(0xFF1E40AF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: secondaryTextColor,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: _timeframeKeys.map((key) {
                final count = allGoals.where((g) {
                  if (g.timeframe != key) return false;
                  if (!showCompleted && g.isDone) return false;
                  return true;
                }).length;

                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.tr('tab_$key')),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _timeframeKeys.map((timeframeKey) {
          final columnGoals = allGoals.where((g) {
            if (g.timeframe != timeframeKey) return false;
            if (!showCompleted && g.isDone) return false;
            return true;
          }).toList();

          if (goalsAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (columnGoals.isEmpty) {
            return _buildEmptyColumn(
              context: context,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              timeframeKey: timeframeKey,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
            itemCount: columnGoals.length,
            itemBuilder: (context, index) {
              final goal = columnGoals[index];
              return GoalCard(goal: goal);
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GoalFormModal.show(context),
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.flag_rounded, size: 20),
        label: Text(
          context.tr('add_goal_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildEmptyColumn({
    required BuildContext context,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String timeframeKey,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎯', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_goals_column_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('no_goals_column_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => GoalFormModal.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('add_first_goal_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
