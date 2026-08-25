import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../life_score/providers/life_score_provider.dart';
import '../../life_score/widgets/life_score_widget.dart';

/// Conditional Weekly Life Score card for the Home Feed.
///
/// Surfaces the user's computed Weekly Life Score gauge and qualitative label.
/// Hides itself entirely on fresh accounts with zero activity / 0 score.
class HomeLifeScoreWidget extends ConsumerWidget {
  const HomeLifeScoreWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(currentLiveLifeScoreProvider);

    // Skip entirely on fresh account with zero activity this week
    final hasAnyData = score.total > 0 ||
        score.breakdown.tasks > 0 ||
        score.breakdown.habits > 0 ||
        score.breakdown.energy > 0 ||
        score.breakdown.learning > 0 ||
        score.breakdown.checkins > 0 ||
        score.breakdown.goals > 0;

    if (!hasAnyData) {
      return const SizedBox.shrink();
    }

    return const LifeScoreWidget();
  }
}
