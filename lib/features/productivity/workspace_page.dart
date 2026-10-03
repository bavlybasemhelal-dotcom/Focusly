import 'desktop_settings_card.dart';
import 'study_session_section.dart';
import 'analytics_page.dart';
import '../body_metrics/body_metrics_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/calendar_clock.dart';
import '../../core/data/firestore_provider.dart';
import '../../core/data/completion_ledger.dart';
import '../spaced_repetition/providers/flashcards_provider.dart';
import '../spaced_repetition/review_session_page.dart';
import '../reading_tracker/books_shelves_page.dart';
import '../course_tracker/course_tracker_page.dart';
import '../learning_paths/learning_paths_page.dart';
import '../tasks/providers/tasks_provider.dart';
import '../pomodoro/providers/pomodoro_provider.dart';
import '../contacts/contacts_page.dart';
import '../habits/habits_screen.dart';
import 'productivity_page.dart';
import 'providers/workspace_preferences.dart';
import 'habit_calendar_page.dart';

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String arabic, String english) => ar ? arabic : english;
    final prefs = ref.watch(workspacePreferencesProvider);
    final account = ref.watch(currentUserIdProvider);
    final db = ref.watch(firestoreProvider);
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('مساحة العمل الشخصية', 'Personal workspace')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: t('جلسة تعلم', 'Learning session')),
              Tab(text: t('صحتي وعاداتي', 'Health & habits')),
              Tab(text: t('مصادر الأرقام', 'Statistics sources')),
              Tab(text: t('تخصيص', 'Customize')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t(
                    'اختار وقتًا للتعلم وابدأ بالمراجعات المستحقة، ثم درس أو قراءة. التقدم بيتحفظ في أقسامه الأصلية.',
                    'Start with due reviews, then a lesson or reading. Progress stays in its original module.',
                  ),
                ),
                const StudySessionSection(),
                ref
                    .watch(flashcardsStreamProvider)
                    .when(
                      data: (_) => Builder(
                        builder: (_) {
                          final cards = ref.watch(dueFlashcardsProvider);
                          return ListTile(
                            leading: const Icon(Icons.style),
                            title: Text(
                              t(
                                '${cards.length} كارت مستحق للمراجعة',
                                '${cards.length} cards due',
                              ),
                            ),
                            trailing: FilledButton(
                              onPressed: cards.isEmpty
                                  ? null
                                  : () => ReviewSessionPage.start(
                                      context,
                                      ref,
                                      cards,
                                    ),
                              child: Text(t('ابدأ', 'Start')),
                            ),
                          );
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(
                        t('تعذر تحميل المراجعات.', 'Could not load reviews.'),
                      ),
                    ),
                for (final action in [
                  (
                    Icons.school,
                    t('كمل درس في كورس', 'Continue a course lesson'),
                    const CourseTrackerPage(),
                  ),
                  (
                    Icons.menu_book,
                    t('كمل قراءة كتاب', 'Continue reading'),
                    const BooksShelvesPage(),
                  ),
                  (
                    Icons.route,
                    t(
                      'خطوتي التالية في مسار التعلم',
                      'Next learning path step',
                    ),
                    const LearningPathsPage(),
                  ),
                ])
                  Card(
                    child: ListTile(
                      leading: Icon(action.$1),
                      title: Text(action.$2),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(action.$3),
                    ),
                  ),
                Text(
                  t(
                    'يمكن ربط مهام التعلم بهدف وإضافة مصادر وروابط من أدوات الإنتاجية.',
                    'Link learning tasks to goals and add source links in productivity tools.',
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: Text(
                    t(
                      'تقويم العادات وسلسلة الأيام',
                      'Habit calendar & dated streak',
                    ),
                  ),
                  leading: const Icon(Icons.calendar_month),
                  onTap: () => open(const HabitCalendarPage()),
                ),
                ListTile(
                  title: Text(t('عاداتي', 'My habits')),
                  onTap: () => open(const HabitsScreen()),
                ),
                ListTile(
                  title: Text(
                    t('العلاقات والتواصل', 'Relationships & contacts'),
                  ),
                  onTap: () => open(const ContactsPage()),
                ),
                DropdownButtonFormField<String>(
                  initialValue: prefs['weightUnit'] as String? ?? 'kg',
                  decoration: InputDecoration(
                    labelText: t('وحدة عرض الوزن', 'Weight display unit'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'lb', child: Text('lb')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(workspacePreferencesProvider.notifier)
                          .set('weightUnit', value);
                    }
                  },
                ),
                Text(
                  t(
                    'الأوزان محفوظة بالكيلوغرام، والتحويل للرطل للعرض فقط. الضغط بوحدة mmHg والنبض بالدقيقة. السجل وصفي شخصي ولا يصدر تشخيصًا.',
                    'Weights are stored in kg; lb is a display conversion. Pressure uses mmHg and pulse bpm. This is a personal descriptive log.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(
                    t('سجل القياسات والرسوم', 'Measurements and charts'),
                  ),
                  onTap: () => open(const BodyMetricsPage()),
                ),
                ref
                    .watch(productivityCollectionProvider('bodyMetrics'))
                    .when(
                      data: (records) {
                        final sorted =
                            records
                                .where(
                                  (entry) =>
                                      entry['weight'] is num ||
                                      entry['bpSystolic'] is num ||
                                      entry['pulse'] is num,
                                )
                                .toList()
                              ..sort(
                                (a, b) =>
                                    ((b['date'] as Timestamp?)?.toDate() ??
                                            DateTime(1970))
                                        .compareTo(
                                          (a['date'] as Timestamp?)?.toDate() ??
                                              DateTime(1970),
                                        ),
                              );
                        final pounds = prefs['weightUnit'] == 'lb';
                        return Column(
                          children: [
                            for (final record in sorted.take(30))
                              ListTile(
                                title: Text(
                                  [
                                    if (record['weight'] is num)
                                      '${((record['weight'] as num).toDouble() * (pounds ? 2.2046226218 : 1)).toStringAsFixed(1)} ${pounds ? 'lb' : 'kg'}',
                                    if (record['bpSystolic'] is num &&
                                        record['bpDiastolic'] is num)
                                      '${record['bpSystolic']}/${record['bpDiastolic']} mmHg',
                                    if (record['pulse'] is num)
                                      '${record['pulse']} bpm',
                                  ].join(' • '),
                                ),
                                subtitle: Text(
                                  record['date'] is Timestamp
                                      ? CompletionLedger.dateKey(
                                          (record['date'] as Timestamp)
                                              .toDate(),
                                        )
                                      : record['id'] as String,
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(
                        t(
                          'تعذر تحميل القياسات.',
                          'Could not load measurements.',
                        ),
                      ),
                    ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t(
                    'كل رقم هنا مبني على سجل بتاريخ. عدم وجود سجل يعني بيانات غير متاحة، مش صفر مؤكد. وقت الأولويات تقدير منفصل عن وقت التركيز المسجل.',
                    'Figures use dated records. A missing record means unavailable data. Planned estimates are separate from logged focus time.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(
                    t(
                      'قارن فترات وافتح مصدر كل رقم',
                      'Compare periods and inspect each source',
                    ),
                  ),
                  onTap: () => open(const AnalyticsPage()),
                ),
                ref
                    .watch(tasksStreamProvider)
                    .when(
                      data: (tasks) {
                        final today = ref.watch(calendarClockProvider);
                        final start = DateTime.parse(
                          CompletionLedger.weekKey(today),
                        );
                        final completed = tasks
                            .where(
                              (task) =>
                                  task.doneAt != null &&
                                  !calendarDay(task.doneAt!).isBefore(start) &&
                                  !calendarDay(task.doneAt!).isAfter(today),
                            )
                            .toList();
                        return ExpansionTile(
                          title: Text(
                            t(
                              'مهام مكتملة هذا الأسبوع: ${completed.length}',
                              'Tasks completed this week: ${completed.length}',
                            ),
                          ),
                          subtitle: Text(
                            t(
                              'المصدر: تاريخ الإنجاز الفعلي، والأسبوع يبدأ السبت.',
                              'Source: actual completion date; weeks begin Saturday.',
                            ),
                          ),
                          children: [
                            for (final task in completed)
                              ListTile(
                                title: Text(task.title),
                                subtitle: Text(
                                  CompletionLedger.dateKey(task.doneAt!),
                                ),
                                trailing: Text(
                                  task.isGroupAssigned
                                      ? t('تكليف', 'Assigned')
                                      : t('شخصية', 'Personal'),
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(
                        t('تعذر تحميل المهام.', 'Could not load tasks.'),
                      ),
                    ),
                ref
                    .watch(pomodoroLogsStreamProvider)
                    .when(
                      data: (logs) {
                        final today = ref.watch(calendarClockProvider);
                        final current = logs
                            .where((log) => calendarDay(log.date) == today)
                            .toList();
                        final seconds = current.fold<int>(
                          0,
                          (totalSeconds, log) =>
                              totalSeconds + log.durationSeconds,
                        );
                        return ExpansionTile(
                          title: Text(
                            t(
                              'تركيز اليوم: ${(seconds / 60).toStringAsFixed(1)} دقيقة',
                              'Today focus: ${(seconds / 60).toStringAsFixed(1)} min',
                            ),
                          ),
                          subtitle: Text(
                            t(
                              'المصدر: جلسات Pomodoro المحفوظة، ويشمل الجلسات الجزئية.',
                              'Source: saved Pomodoro sessions, including partial sessions.',
                            ),
                          ),
                          children: [
                            for (final log in current)
                              ListTile(
                                title: Text(log.taskTitle),
                                subtitle: Text(
                                  '${log.durationSeconds}s · ${log.partial ? t('جزئية', 'Partial') : t('كاملة', 'Full')}',
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(
                        t('تعذر تحميل الجلسات.', 'Could not load sessions.'),
                      ),
                    ),
                ListTile(
                  title: Text(
                    t('نسخة JSON وتصدير CSV', 'JSON backup & CSV export'),
                  ),
                  onTap: () => open(const ProductivityPage(initialTab: 3)),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const DesktopSettingsCard(),
                if (account != null)
                  StreamBuilder(
                    stream: db.collection('users').doc(account).snapshots(),
                    builder: (context, snapshot) => SwitchListTile(
                      title: Text(
                        t(
                          'شارك نشاطًا عامًا مع الجروبات',
                          'Share general activity with groups',
                        ),
                      ),
                      subtitle: Text(
                        t(
                          'مقفول افتراضيًا؛ عناوين المهام والتفاصيل الشخصية تظل خاصة.',
                          'Off by default; task titles and private details stay private.',
                        ),
                      ),
                      value:
                          snapshot.data?.data()?['sharePersonalActivity'] ==
                          true,
                      onChanged: snapshot.hasData
                          ? (value) async {
                              try {
                                await db
                                    .collection('users')
                                    .doc(account)
                                    .update({'sharePersonalActivity': value});
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t('تعذر الحفظ', 'Could not save'),
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  ),
                Text(
                  t(
                    'إخفاء قسم يغير التنقل فقط، وبياناته تظل محفوظة. الاختصارات: Ctrl+K للبحث، Ctrl+N لالتقاط فكرة، Ctrl+D ليومي.',
                    'Hiding a module affects navigation and keeps its data. Ctrl+K search, Ctrl+N capture, Ctrl+D my day.',
                  ),
                ),
                for (final module in [
                  ('gtd', t('تنظيم GTD', 'GTD')),
                  ('para', 'PARA'),
                  ('goals', t('الأهداف', 'Goals')),
                  ('wellness', t('الطقوس والطاقة', 'Rituals & energy')),
                  ('relationships', t('العلاقات', 'Relationships')),
                  ('learning', t('التعلم', 'Learning')),
                  ('health', t('الصحة', 'Health')),
                  ('finance', t('المالية', 'Finance')),
                  ('analytics', t('التحليلات', 'Analytics')),
                ])
                  SwitchListTile(
                    title: Text(module.$2),
                    value: moduleVisible(prefs, module.$1),
                    onChanged: (value) async {
                      final hidden = Set<String>.from(
                        prefs['hiddenModules'] as List? ?? [],
                      );
                      if (value) {
                        hidden.remove(module.$1);
                      } else {
                        hidden.add(module.$1);
                      }
                      await ref
                          .read(workspacePreferencesProvider.notifier)
                          .set('hiddenModules', hidden.toList());
                    },
                  ),
                DropdownButtonFormField<int>(
                  initialValue: prefs['favoriteTab'] as int? ?? 0,
                  decoration: InputDecoration(
                    labelText: t(
                      'صفحة البداية المفضلة',
                      'Favorite starting tab',
                    ),
                  ),
                  items: [
                    for (final item in [
                      (0, t('الرئيسية', 'Home')),
                      (1, t('المهام', 'Tasks')),
                      (2, t('التقويم', 'Calendar')),
                      (3, t('العادات', 'Habits')),
                      (4, 'Pomodoro'),
                    ])
                      DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(workspacePreferencesProvider.notifier)
                          .set('favoriteTab', value);
                    }
                  },
                ),
                if (account != null)
                  OutlinedButton(
                    onPressed: () async {
                      await db
                          .collection('users')
                          .doc(account)
                          .collection('productivity')
                          .doc('preferences')
                          .set({
                            'hiddenModules': prefs['hiddenModules'] ?? [],
                            'favoriteTab': prefs['favoriteTab'] ?? 0,
                          });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t(
                                'اتحفظت تفضيلاتك ضمن النسخة الاحتياطية.',
                                'Preferences included in your backup.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      t(
                        'ضم التفضيلات لنسختي الاحتياطية',
                        'Include preferences in backup',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
