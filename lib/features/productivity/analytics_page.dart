import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/calendar_clock.dart';
import '../../core/data/completion_ledger.dart';
import '../tasks/providers/tasks_provider.dart';
import '../tasks/models/task_model.dart';
import '../pomodoro/providers/pomodoro_provider.dart';
import '../time_audit/providers/time_audit_provider.dart';
import '../para/providers/para_provider.dart';

class DatedTaskSummary {
  DatedTaskSummary(List<TaskModel> tasks, DateTime start, DateTime end) {
    bool inside(DateTime date) =>
        !calendarDay(date).isBefore(start) && calendarDay(date).isBefore(end);
    eligible = tasks
        .where(
          (task) =>
              inside(task.date) ||
              (task.done && task.doneAt != null && inside(task.doneAt!)),
        )
        .toList();
    completed = eligible
        .where(
          (task) => task.done && task.doneAt != null && inside(task.doneAt!),
        )
        .toList();
    unknown = tasks.where((task) => task.done && task.doneAt == null).length;
  }
  late final List<TaskModel> eligible, completed;
  late final int unknown;
  int get percentage =>
      eligible.isEmpty ? 0 : (completed.length / eligible.length * 100).round();
}

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int days = 7;
  String? project;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksStreamProvider),
        focus = ref.watch(pomodoroLogsStreamProvider),
        manual = ref.watch(timeAuditLogsStreamProvider),
        projects = ref.watch(allParaProjectsStreamProvider);
    final today = ref.watch(calendarClockProvider),
        end = calendarDay(today, 1),
        start = calendarDay(end, -days),
        previous = calendarDay(start, -days);
    final sources = [tasks, focus, manual, projects];
    return Scaffold(
      appBar: AppBar(
        title: Text(t('أرقام قابلة للمراجعة', 'Auditable figures')),
      ),
      body: sources.any((value) => value.hasError)
          ? Center(
              child: TextButton(
                onPressed: () {
                  ref.invalidate(tasksStreamProvider);
                  ref.invalidate(pomodoroLogsStreamProvider);
                  ref.invalidate(timeAuditLogsStreamProvider);
                  ref.invalidate(allParaProjectsStreamProvider);
                },
                child: Text(
                  t('تعذر التحميل؛ أعد المحاولة', 'Could not load; retry'),
                ),
              ),
            )
          : sources.any((value) => !value.hasValue || value.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final records = tasks.value!
                    .where(
                      (task) => project == null || task.projectId == project,
                    )
                    .toList();
                final current = DatedTaskSummary(records, start, end),
                    old = DatedTaskSummary(records, previous, start);
                bool within(DateTime date, DateTime a, DateTime b) =>
                    !calendarDay(date).isBefore(a) &&
                    calendarDay(date).isBefore(b);
                final currentFocus = focus.value!
                    .where((log) => within(log.date, start, end))
                    .fold<int>(0, (total, log) => total + log.durationSeconds);
                final oldFocus = focus.value!
                    .where((log) => within(log.date, previous, start))
                    .fold<int>(0, (total, log) => total + log.durationSeconds);
                final currentManual = manual.value!
                    .where((log) => within(log.date, start, end))
                    .fold<double>(0, (total, log) => total + log.hours);
                final oldManual = manual.value!
                    .where((log) => within(log.date, previous, start))
                    .fold<double>(0, (total, log) => total + log.hours);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButton<int>(
                      value: days,
                      items: [7, 30, 90]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value ${t('يوم', 'days')}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => days = value!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: project,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t(
                          'المشروع — للمهام فقط',
                          'Project — tasks only',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(t('كل المشاريع', 'All projects')),
                        ),
                        for (final item in projects.value!)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                      ],
                      onChanged: (value) => setState(() => project = value),
                    ),
                    Text(
                      '${CompletionLedger.dateKey(start)} → ${CompletionLedger.dateKey(today)}',
                    ),
                    Text(
                      t(
                        'المقارنة بفترة سابقة بنفس عدد الأيام. التركيز والإدخال اليدوي يُعرضان منفصلين لأنهما قد يصفان نفس النشاط؛ لا نجمعهما كوقت مؤكد.',
                        'Comparison uses the preceding equal period. Timer and manual time stay separate because they may describe the same activity.',
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(t('المقياس', 'Metric'))),
                          DataColumn(label: Text(t('الحالي', 'Current'))),
                          DataColumn(label: Text(t('السابق', 'Previous'))),
                        ],
                        rows: [
                          DataRow(
                            cells: [
                              DataCell(
                                Text(t('المهام المكتملة', 'Completed tasks')),
                              ),
                              DataCell(Text('${current.completed.length}')),
                              DataCell(Text('${old.completed.length}')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(Text(t('الإنجاز', 'Completion'))),
                              DataCell(Text('${current.percentage}%')),
                              DataCell(Text('${old.percentage}%')),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  t(
                                    'دقائق التركيز — كل المشاريع',
                                    'Focus min — all projects',
                                  ),
                                ),
                              ),
                              DataCell(
                                Text((currentFocus / 60).toStringAsFixed(1)),
                              ),
                              DataCell(
                                Text((oldFocus / 60).toStringAsFixed(1)),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  t(
                                    'ساعات يدوية — كل المشاريع',
                                    'Manual hours — all projects',
                                  ),
                                ),
                              ),
                              DataCell(Text(currentManual.toStringAsFixed(1))),
                              DataCell(Text(oldManual.toStringAsFixed(1))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      t(
                        'الإنجاز = مهام أُنجزت بتاريخ محفوظ داخل الفترة ÷ اتحاد المهام المجدولة فيها والمهام المُنجزة فيها. مهام قديمة مكتملة بلا تاريخ: ${current.unknown}؛ لا نوزعها على أيام مخترعة.',
                        'Completion = tasks with dated completion in the period / union of scheduled tasks and tasks completed in the period. ${current.unknown} legacy completed tasks lack dates and cannot be assigned invented history.',
                      ),
                    ),
                    ExpansionTile(
                      title: Text(
                        t(
                          'البسط: ${current.completed.length} مهام',
                          'Numerator: ${current.completed.length} tasks',
                        ),
                      ),
                      children: [
                        for (final task in current.completed)
                          ListTile(
                            title: Text(task.title),
                            subtitle: Text(
                              CompletionLedger.dateKey(task.doneAt!),
                            ),
                          ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(
                        t(
                          'المقام: ${current.eligible.length} مهام',
                          'Denominator: ${current.eligible.length} tasks',
                        ),
                      ),
                      children: [
                        for (final task in current.eligible)
                          ListTile(
                            title: Text(task.title),
                            subtitle: Text(CompletionLedger.dateKey(task.date)),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}
