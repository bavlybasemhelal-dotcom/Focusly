import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/data/calendar_clock.dart';
import '../../../core/data/firestore_provider.dart';
import '../../../core/data/completion_ledger.dart';

class DatedSkillSparkline extends ConsumerWidget {
  const DatedSkillSparkline({
    super.key,
    required this.skillId,
    required this.color,
  });
  final String skillId;
  final Color color;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final today = ref.watch(calendarClockProvider);
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder(
      stream: ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('skills')
          .doc(skillId)
          .collection('dailyProgress')
          .where(
            'date',
            isGreaterThanOrEqualTo: CompletionLedger.dateKey(
              calendarDay(today, -6),
            ),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'لا يوجد سجل مؤرخ'
                : 'No dated history',
            style: const TextStyle(fontSize: 9),
          );
        }
        final values = <int, double>{};
        for (final doc in snapshot.data!.docs) {
          final date = DateTime.tryParse(doc.data()['date'] as String? ?? '');
          if (date == null) continue;
          final position = 6 - calendarDaysBetween(date, today);
          if (position >= 0 && position <= 6) {
            values[position] = (doc.data()['totalXp'] as num?)?.toDouble() ?? 0;
          }
        }
        return Tooltip(
          message: Localizations.localeOf(context).languageCode == 'ar'
              ? 'نقاط المهارة في الأيام المسجلة فقط؛ الفراغ يعني بيانات غير متاحة.'
              : 'Skill XP on recorded dates only; gaps mean unavailable data.',
          child: SizedBox(
            width: 80,
            height: 28,
            child: CustomPaint(painter: _DatedPainter(values, color)),
          ),
        );
      },
    );
  }
}

class _DatedPainter extends CustomPainter {
  _DatedPainter(this.values, this.color);
  final Map<int, double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final sorted = values.values.toList()..sort();
    final min = sorted.first, max = sorted.last;
    final range = max > min ? max - min : 1.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    Offset? previous;
    int? previousIndex;
    for (final index in values.keys.toList()..sort()) {
      final point = Offset(
        4 + index * (size.width - 8) / 6,
        size.height - 4 - (values[index]! - min) / range * (size.height - 8),
      );
      if (previous != null && index == previousIndex! + 1) {
        canvas.drawLine(previous, point, paint);
      }
      canvas.drawCircle(point, 2.5, paint);
      previous = point;
      previousIndex = index;
    }
  }

  @override
  bool shouldRepaint(covariant _DatedPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString() ||
      oldDelegate.color != color;
}
