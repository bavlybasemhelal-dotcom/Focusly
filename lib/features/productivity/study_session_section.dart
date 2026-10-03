import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import '../../core/data/calendar_clock.dart';
import '../goals/providers/goals_provider.dart';
import '../pomodoro/providers/pomodoro_provider.dart';
import '../pomodoro/pomodoro_screen.dart';
import 'productivity_page.dart';
import 'search_navigation.dart';
import 'services/study_session_service.dart';

class StudySessionSection extends ConsumerStatefulWidget {
  const StudySessionSection({super.key});
  @override
  ConsumerState<StudySessionSection> createState() =>
      _StudySessionSectionState();
}

class _StudySessionSectionState extends ConsumerState<StudySessionSection> {
  String? goal;
  bool busy = false;
  Future<void> start(Map<String, dynamic> source, bool focus) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || busy) return;
    setState(() => busy = true);
    try {
      final task = await StudySessionService(ref.read(firestoreProvider)).plan(
        uid: uid,
        collection: source['collection'] as String,
        sourceId: source['id'] as String,
        date: ref.read(calendarClockProvider),
        goalId: goal,
      );
      if (!mounted || ref.read(currentUserIdProvider) != uid) return;
      if (focus) {
        ref
            .read(pomodoroTimerProvider.notifier)
            .setSelectedTask(task.id, task.title);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PomodoroScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('اتضافت جلسة التعلم ليومي', 'Learning session added to My day'),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsStreamProvider).value ?? [];
    return Column(
      children: [
        Text(
          t(
            'جلستي القادمة — مهمة لتنظيم الوقت، ونقاط التعلم تُحسب في المصدر الأصلي فقط.',
            'Next session — a task organizes your time; learning XP comes from the original source.',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: goals.any((item) => item.id == goal) ? goal : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: t('هدف المذاكرة — اختياري', 'Learning goal — optional'),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(t('بدون هدف', 'No goal')),
            ),
            for (final item in goals.where((item) => !item.isDone))
              DropdownMenuItem(value: item.id, child: Text(item.title)),
          ],
          onChanged: busy ? null : (value) => setState(() => goal = value),
        ),
        for (final collection in ['courses', 'books', 'learningPaths'])
          ref
              .watch(productivityCollectionProvider(collection))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  t(
                    'تعذر تحميل مصادر التعلم',
                    'Could not load learning sources',
                  ),
                ),
                data: (sources) => Column(
                  children: [
                    for (final source
                        in sources
                            .where(
                              (data) =>
                                  data['deletionPending'] != true &&
                                  StudySessionService.nextStep(
                                        collection,
                                        data,
                                      ) >=
                                      0 &&
                                  (collection != 'books' ||
                                      (data['currentPage'] as num? ?? 0) <
                                          (data['totalPages'] as num? ?? 0)) &&
                                  (collection != 'courses' ||
                                      (data['completedLessons'] as num? ?? 0) <
                                          (data['totalLessons'] as num? ?? 0)),
                            )
                            .take(10))
                      Card(
                        child: ListTile(
                          title: Text(source['title'] as String? ?? ''),
                          subtitle: Text(
                            '${moduleLabel(collection, Localizations.localeOf(context).languageCode == 'ar')} • ${t('الخطوة التالية', 'Next step')}: ${StudySessionService.nextStep(collection, source) + 1}',
                          ),
                          onTap: () => openSearchResult(context, {
                            ...source,
                            'collection': collection,
                          }),
                          trailing: PopupMenuButton<bool>(
                            enabled: !busy,
                            onSelected: (focus) => start({
                              ...source,
                              'collection': collection,
                            }, focus),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: false,
                                child: Text(
                                  t('خطط لها اليوم', 'Plan for today'),
                                ),
                              ),
                              PopupMenuItem(
                                value: true,
                                child: Text(
                                  t('ابدأ جلسة تركيز', 'Start focus session'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ],
    );
  }
}
