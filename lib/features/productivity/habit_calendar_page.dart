import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/calendar_clock.dart';
import '../../core/data/firestore_provider.dart';
import '../../core/data/completion_ledger.dart';
import '../habits/providers/habits_provider.dart';
import '../habits/models/habit_model.dart';
import '../habits/services/habit_history_service.dart';
import '../progress/services/progress_service.dart';

class HabitCalendarPage extends ConsumerStatefulWidget {
  const HabitCalendarPage({super.key, this.initialHabitId});
  final String? initialHabitId;
  @override
  ConsumerState<HabitCalendarPage> createState() => _HabitCalendarPageState();
}

class _HabitCalendarPageState extends ConsumerState<HabitCalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? selected;
  @override
  void initState() {
    super.initState();
    selected = widget.initialHabitId;
  }

  bool saving = false;
  String? error;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  Future<void> _mark(HabitModel habit, DateTime date, bool completed) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || saving) return;
    final today = ref.read(calendarClockProvider);
    final retro = date != today;
    if (retro) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(t('إدخال بأثر رجعي', 'Retrospective entry')),
          content: Text(
            t(
              'التاريخ هيتحفظ كما هو، ولن يحتسب كإنجاز حي في تحديات الجروب.',
              'The selected date is preserved and excluded from live group challenges.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(t('تأكيد', 'Confirm')),
            ),
          ],
        ),
      );
      if (confirm != true ||
          !mounted ||
          ref.read(currentUserIdProvider) != uid) {
        return;
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final db = ref.read(firestoreProvider);
      await HabitHistoryService(db).setCompleted(
        uid: uid,
        habitId: habit.id,
        date: date,
        completed: completed,
        retrospective: retro,
        now: today,
      );
      if (completed) {
        final event = 'habit_${habit.id}_${CompletionLedger.dateKey(date)}';
        if (habit.isGroupAssigned) {
          await CompletionLedger(db).award(
            uid: uid,
            eventId: event,
            sourceId: habit.id,
            sourceType: 'habit',
            amount: 0,
            label: habit.title,
          );
          await CompletionLedger(db).syncGroups(uid: uid, eventId: event);
        } else {
          await ProgressService(firestore: db).awardXp(
            5,
            uid: uid,
            eventId: event,
            sourceId: habit.id,
            sourceType: 'habit',
            source: habit.title,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'تعذر حفظ اليوم. حاول تاني.',
            'Could not save this date. Retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final habits = ref.watch(habitsStreamProvider).value ?? <HabitModel>[];
    final habit =
        habits.where((item) => item.id == selected).firstOrNull ??
        habits.firstOrNull;
    final today = ref.watch(calendarClockProvider);
    final start = CompletionLedger.dateKey(month);
    final end = CompletionLedger.dateKey(
      DateTime(month.year, month.month + 1, 0),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t('تقويم العادات', 'Habit calendar'))),
      body: habit == null || uid == null
          ? Center(
              child: Text(t('أضف عادة عشان تبدأ.', 'Add a habit to start.')),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButton<String>(
                  value: habit.id,
                  isExpanded: true,
                  items: [
                    for (final item in habits)
                      DropdownMenuItem(value: item.id, child: Text(item.title)),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => selected = value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: t('الشهر السابق', 'Previous month'),
                      onPressed: () => setState(
                        () => month = DateTime(month.year, month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                    ),
                    IconButton(
                      tooltip: t('الشهر التالي', 'Next month'),
                      onPressed:
                          month.year == today.year && month.month == today.month
                          ? null
                          : () => setState(
                              () =>
                                  month = DateTime(month.year, month.month + 1),
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Text(
                  t(
                    'سلسلة متتالية: ${habit.streak} يوم محدد · الإدخال المستقبلي مقفول.',
                    'Streak: ${habit.streak} scheduled days · future entries are disabled.',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (saving) const LinearProgressIndicator(),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref
                      .watch(firestoreProvider)
                      .collection('users')
                      .doc(uid)
                      .collection('habitLogs')
                      .where('date', isGreaterThanOrEqualTo: start)
                      .where('date', isLessThanOrEqualTo: end)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        t(
                          'تعذر تحميل التقويم.',
                          'Could not load the calendar.',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final done = snapshot.data!.docs
                        .where(
                          (doc) =>
                              doc.data()['habitId'] == habit.id &&
                              doc.data()['completed'] == true,
                        )
                        .map((doc) => doc.data()['date'] as String)
                        .toSet();
                    return GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (
                          var index = 0;
                          index < DateTime(month.year, month.month + 1, 0).day;
                          index++
                        )
                          Builder(
                            builder: (_) {
                              final date = calendarDay(month, index);
                              final checked = done.contains(
                                CompletionLedger.dateKey(date),
                              );
                              final allowed =
                                  !date.isAfter(today) &&
                                  !date.isBefore(
                                    calendarDay(habit.createdAt),
                                  ) &&
                                  habit.weekdays.contains(date.weekday) &&
                                  !habit.isCountMode;
                              return Padding(
                                padding: const EdgeInsets.all(3),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: checked
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : null,
                                  ),
                                  onPressed: saving || !allowed
                                      ? null
                                      : () => _mark(habit, date, !checked),
                                  child: Text(
                                    '${index + 1}${checked ? ' ✓' : ''}',
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                if (!habit.isGroupAssigned) ...[
                  Text(t('أيام تكرار العادة', 'Scheduled weekdays')),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(
                            (Localizations.localeOf(context).languageCode ==
                                    'ar'
                                ? const [
                                    'الإثنين',
                                    'الثلاثاء',
                                    'الأربعاء',
                                    'الخميس',
                                    'الجمعة',
                                    'السبت',
                                    'الأحد',
                                  ]
                                : const [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ])[day - 1],
                          ),
                          selected: habit.weekdays.contains(day),
                          onSelected: saving
                              ? null
                              : (value) async {
                                  final values = habit.weekdays.toSet();
                                  if (value) {
                                    values.add(day);
                                  } else {
                                    values.remove(day);
                                  }
                                  if (values.isEmpty) return;
                                  try {
                                    await ref
                                        .read(firestoreProvider)
                                        .collection('users')
                                        .doc(uid)
                                        .collection('habits')
                                        .doc(habit.id)
                                        .update({
                                          'weekdays': values.toList()..sort(),
                                        });
                                  } catch (_) {
                                    if (mounted) {
                                      setState(
                                        () => error = t(
                                          'تعذر حفظ أيام التكرار.',
                                          'Could not save weekdays.',
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                    ],
                  ),
                  Text(
                    t(
                      'الأيام غير المحددة لا تكسر السلسلة. العدّاد الجماعي يظهر في بطاقة التكليف.',
                      'Unscheduled days do not break a streak. Assignment counters appear on their cards.',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
