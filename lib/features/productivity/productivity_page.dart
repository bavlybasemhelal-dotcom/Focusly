import 'workspace_templates_page.dart';
import 'search_navigation.dart';
import 'outbox_page.dart';
import '../contacts/providers/contacts_provider.dart';
import '../contacts/services/contact_reminder_service.dart';
import '../../core/data/firestore_paging.dart';
import 'providers/workspace_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/data/calendar_clock.dart';
import '../../core/data/completion_ledger.dart';
import '../../core/data/firestore_provider.dart';
import '../../core/services/notification_init_service.dart';
import '../../core/notifications/managed_notification_sender.dart';
import '../tasks/providers/tasks_provider.dart';
import '../tasks/models/task_model.dart';
import '../tasks/widgets/add_edit_task_sheet.dart';
import '../habits/habits_screen.dart';
import '../schedule/schedule_screen.dart';
import '../gtd/widgets/quick_capture_sheet.dart';
import '../weekly_review/widgets/weekly_review_wizard.dart';
import 'services/productivity_service.dart';
import 'services/backup_service.dart';
import 'services/trash_service.dart';
import 'task_links_page.dart';

final productivityCollectionProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, name) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return Stream.value([]);
      return ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection(name)
          .limit(500)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList(),
          );
    });

class ProductivityPage extends ConsumerStatefulWidget {
  const ProductivityPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<ProductivityPage> createState() => _ProductivityPageState();
}

class _ProductivityPageState extends ConsumerState<ProductivityPage> {
  bool busy = false;
  final Set<String> selected = {};
  final search = TextEditingController();
  final capacity = TextEditingController(text: '90');
  String filter = 'all';
  String csvCollection = 'tasks';
  List<Map<String, dynamic>> results = [];
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> cursors = {};
  final Set<String> exhausted = {};
  final Map<String, String> templateRequests = {};
  bool hasMore = false;
  Map<String, dynamic> notificationSettings = {};
  List<Map<String, dynamic>> reminders = [];
  String text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  String get uid => ref.read(currentUserIdProvider) ?? '';
  FirebaseFirestore get db => ref.read(firestoreProvider);
  ProductivityService get service => ProductivityService(db);
  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    search.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String account) action) async {
    if (busy || uid.isEmpty) return;
    final account = uid;
    setState(() => busy = true);
    try {
      await action(account);
    } catch (error) {
      if (mounted && uid == account) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _name(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(text('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialog, controller.text.trim());
              }
            },
            child: Text(text('متابعة', 'Continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _loadReminders() async {
    final account = uid;
    if (account.isEmpty) return;
    try {
      final settings = await ManagedNotificationSender.settings(account);
      final upcoming = await NotificationInitService.platformSender.pending(
        account: account,
      );
      if (mounted && uid == account) {
        setState(() {
          notificationSettings = settings;
          reminders = upcoming;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveFile(String data, String name, String mime) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(data)),
      name: name,
      mimeType: mime,
    );
    if (kIsWeb) {
      await file.saveTo(name);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Share.shareXFiles([file]);
      return;
    }
    final destination = await getSaveLocation(suggestedName: name);
    if (destination != null) await file.saveTo(destination.path);
  }

  Future<void> _search(bool more) => _run((account) async {
    final queryText = search.text.trim().toLowerCase();
    if (!more) {
      results = [];
      cursors.clear();
      exhausted.clear();
    }
    final names = filter == 'all'
        ? [
            'tasks',
            'habits',
            'events',
            'inbox',
            'goals',
            'books',
            'courses',
            'learningPaths',
            'contacts',
            'paraProjects',
            'paraResources',
            'knowledge',
          ]
        : [filter];
    var remaining = false;
    final additions = <Map<String, dynamic>>[];
    for (final name in names) {
      if (more && exhausted.contains(name)) continue;
      Query<Map<String, dynamic>> query = db
          .collection('users')
          .doc(account)
          .collection(name)
          .orderBy(FieldPath.documentId)
          .limit(100);
      if (more && cursors[name] != null) {
        query = query.startAfterDocument(cursors[name]!);
      }
      final page = await query.get();
      if (uid != account) return;
      if (page.docs.isNotEmpty) cursors[name] = page.docs.last;
      if (page.docs.length == 100) {
        remaining = true;
      } else {
        exhausted.add(name);
      }
      for (final doc in page.docs) {
        final data = doc.data();
        final haystack = [
          data['title'],
          data['name'],
          data['text'],
          data['content'],
          data['notes'],
          data['note'],
        ].whereType<String>().join(' ').toLowerCase();
        if (queryText.isEmpty || haystack.contains(queryText)) {
          additions.add({...data, 'collection': name, 'id': doc.id});
        }
      }
    }
    if (mounted) {
      setState(() {
        results.addAll(additions);
        hasMore = remaining;
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserIdProvider);
    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(text('أدوات الإنتاجية', 'Productivity tools')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: text('يومي', 'My day')),
              Tab(text: text('بحث', 'Search')),
              Tab(text: text('تكرار وقوالب', 'Repeat & templates')),
              Tab(text: text('بياناتي', 'My data')),
              Tab(text: text('تذكيرات', 'Reminders')),
            ],
          ),
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  _today(),
                  _searchTab(),
                  _templates(),
                  _data(),
                  _reminders(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: text('التقاط فكرة', 'Quick capture'),
          onPressed: busy ? null : () => QuickCaptureSheet.show(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _today() {
    final date = ref.watch(calendarClockProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final raw = ref.watch(productivityCollectionProvider('tasks'));
    final plans = ref.watch(productivityCollectionProvider('dailyPlans'));
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(tasksStreamProvider),
          child: Text(text('إعادة المحاولة', 'Retry')),
        ),
      ),
      data: (tasks) {
        final todayPlan = plans.value
            ?.where((plan) => plan['date'] == CompletionLedger.dateKey(date))
            .firstOrNull;
        final ids =
            (todayPlan?['taskIds'] as List?)?.whereType<String>().toList() ??
            <String>[];
        final metadata = {
          for (final record in raw.value ?? <Map<String, dynamic>>[])
            record['id'] as String: record,
        };
        final suggestions = ProductivityService.suggest(
          tasks: tasks,
          today: date,
          availableMinutes: int.tryParse(capacity.text) ?? 90,
          metadata: metadata,
        );
        final due = tasks
            .where(
              (task) =>
                  !task.done &&
                  !calendarDay(task.deadline ?? task.date).isAfter(date) &&
                  !['reference', 'someday'].contains(task.listType),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Text(
              CompletionLedger.dateKey(date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              text(
                'اختار بحد أقصى ٣ أولويات. الاقتراحات حسب الموعد والأولوية والوقت المتاح؛ الوقت تقدير، مش وقت مسجّل.',
                'Choose up to three priorities. Suggestions use due date, priority and available time; duration is an estimate.',
              ),
            ),
            TextField(
              controller: capacity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: text(
                  'وقت المهام المتاح بالدقائق',
                  'Available task minutes',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            for (final suggestion in suggestions)
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(suggestion.task.title),
                subtitle: Text(
                  '${suggestion.minutes} ${text('دقيقة', 'min')} • ${suggestion.reason == 'overdue' ? text('متأخرة', 'Overdue') : text('موعدها اليوم', 'Due today')}',
                ),
              ),
            if (suggestions.isNotEmpty)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _run(
                        (account) => service.setMyDay(
                          account,
                          date,
                          suggestions.map((item) => item.task.id).toList(),
                        ),
                      ),
                child: Text(
                  text(
                    'استخدم الاقتراحات كأولوياتي',
                    'Use suggestions as my priorities',
                  ),
                ),
              ),
            for (final task in due)
              Card(
                child: ListTile(
                  leading: Checkbox(
                    value: ids.contains(task.id),
                    onChanged: busy
                        ? null
                        : (checked) => _run((account) async {
                            final next = List<String>.from(ids);
                            if (checked == true) {
                              next.add(task.id);
                            } else {
                              next.remove(task.id);
                            }
                            await service.setMyDay(account, date, next);
                          }),
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.priority.name}${task.completionMode == 'count' ? ' • ${task.currentCount}/${task.targetCount}' : ''}',
                  ),
                  onTap: () => AddEditTaskSheet.show(context, taskToEdit: task),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'links') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskLinksPage(task: task),
                          ),
                        );
                      }
                      if (value == 'done') {
                        ref
                            .read(tasksControllerProvider)
                            .toggleTaskDone(task, context);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'done',
                        child: Text(text('سجّل التقدم', 'Record progress')),
                      ),
                      PopupMenuItem(
                        value: 'links',
                        child: Text(
                          text(
                            'اعتمادات وروابط ومرفقات',
                            'Dependencies, links & attachments',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (due.isEmpty)
              Text(text('مفيش مهام مستحقة دلوقتي.', 'No tasks are due now.')),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HabitsScreen()),
                  ),
                  child: Text(text('عادات اليوم', 'Daily habits')),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                  ),
                  child: Text(text('التقويم', 'Calendar')),
                ),
                OutlinedButton(
                  onPressed: () => WeeklyReviewWizard.show(context),
                  child: Text(text('مراجعتي الأسبوعية', 'Weekly review')),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _searchTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final saved
              in (ref.watch(workspacePreferencesProvider)['savedSearches']
                          as List? ??
                      [])
                  .whereType<Map>())
            InputChip(
              label: Text(
                '${moduleLabel(saved['collection'] as String, Localizations.localeOf(context).languageCode == 'ar')}: ${saved['query']}',
              ),
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        search.text = saved['query'] as String;
                        filter = saved['collection'] as String;
                      });
                      _search(false);
                    },
              onDeleted: busy
                  ? null
                  : () => _run((_) async {
                      final entries =
                          List<dynamic>.from(
                            ref.read(
                                      workspacePreferencesProvider,
                                    )['savedSearches']
                                    as List? ??
                                [],
                          )..removeWhere(
                            (item) =>
                                item['query'] == saved['query'] &&
                                item['collection'] == saved['collection'],
                          );
                      await ref
                          .read(workspacePreferencesProvider.notifier)
                          .set('savedSearches', entries);
                    }),
            ),
        ],
      ),
      TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(false),
        decoration: InputDecoration(
          labelText: text('بحث في بياناتك', 'Search your data'),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      DropdownButton<String>(
        value: filter,
        isExpanded: true,
        onChanged: busy
            ? null
            : (value) => setState(() {
                filter = value!;
                results = [];
                cursors.clear();
              }),
        items:
            [
                  'all',
                  'tasks',
                  'habits',
                  'events',
                  'inbox',
                  'goals',
                  'books',
                  'courses',
                  'contacts',
                  'paraProjects',
                  'paraResources',
                  'learningPaths',
                  'knowledge',
                ]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'all'
                          ? text('كل الأقسام', 'All modules')
                          : moduleLabel(
                              value,
                              Localizations.localeOf(context).languageCode ==
                                  'ar',
                            ),
                    ),
                  ),
                )
                .toList(),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.bookmark_add),
        label: Text(text('احفظ البحث', 'Save search')),
        onPressed: busy
            ? null
            : () => _run((_) async {
                final entries = List<dynamic>.from(
                  ref.read(workspacePreferencesProvider)['savedSearches']
                          as List? ??
                      [],
                );
                if (entries.length >= 20) {
                  throw StateError('Maximum 20 saved searches');
                }
                if (!entries.any(
                  (item) =>
                      item['query'] == search.text.trim() &&
                      item['collection'] == filter,
                )) {
                  entries.add({
                    'query': search.text.trim(),
                    'collection': filter,
                  });
                }
                await ref
                    .read(workspacePreferencesProvider.notifier)
                    .set('savedSearches', entries);
              }),
      ),
      FilledButton(
        onPressed: busy ? null : () => _search(false),
        child: Text(text('بحث', 'Search')),
      ),
      Text(
        text(
          'البحث بيحمّل ١٠٠ سجل لكل قسم في المرة. «تحميل المزيد» يكمل السجلات الأقدم.',
          'Search reads 100 records per module per page. Load more to include older records.',
        ),
      ),
      for (final record in results)
        ListTile(
          title: Text(
            (record['title'] ??
                    record['name'] ??
                    record['text'] ??
                    record['id'])
                .toString(),
          ),
          subtitle: Text(
            moduleLabel(
              record['collection'] as String,
              Localizations.localeOf(context).languageCode == 'ar',
            ),
          ),
          onTap: () => openSearchResult(context, record),
        ),
      if (hasMore)
        OutlinedButton(
          onPressed: busy ? null : () => _search(true),
          child: Text(text('تحميل المزيد', 'Load more')),
        ),
    ],
  );
  Widget _templates() {
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final templates = ref.watch(
      productivityCollectionProvider('taskTemplates'),
    );
    final recurrences = ref.watch(
      productivityCollectionProvider('taskRecurrences'),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkspaceTemplatesPage()),
          ),
          icon: const Icon(Icons.dashboard_customize),
          label: Text(
            text(
              'قالب مشروع وعادات وروتين',
              'Project, habit and routine template',
            ),
          ),
        ),
        Text(
          text(
            'اختار المهام للقالب أو للعمليات الجماعية. القوالب تعرض عناصرها قبل إضافتها.',
            'Select tasks for a reusable template or bulk actions. Preview template items before adding them.',
          ),
        ),
        for (final task in tasks.where((task) => !task.isGroupAssigned))
          CheckboxListTile(
            value: selected.contains(task.id),
            title: Text(task.title),
            secondary: PopupMenuButton<String>(
              onSelected: (frequency) => _configureRecurrence(task, frequency),
              itemBuilder: (_) => [
                for (final pair in [
                  (
                    'skip',
                    text(
                      'تخطي هذه النسخة المتكررة',
                      'Skip this recurring occurrence',
                    ),
                  ),
                  ('daily', text('يوميًا', 'Daily')),
                  ('weekly', text('أسبوعيًا', 'Weekly')),
                  ('monthly', text('شهريًا', 'Monthly')),
                  (
                    'interval',
                    text(
                      'كل عدد أيام / بعد الإنجاز',
                      'Every N days / after completion',
                    ),
                  ),
                ])
                  PopupMenuItem(value: pair.$1, child: Text(pair.$2)),
              ],
            ),
            onChanged: busy
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      selected.add(task.id);
                    } else {
                      selected.remove(task.id);
                    }
                  }),
          ),
        FilledButton(
          onPressed: busy || selected.isEmpty
              ? null
              : () async {
                  final name = await _name(text('اسم القالب', 'Template name'));
                  if (name != null) {
                    await _run(
                      (account) => service.saveTemplate(
                        account,
                        name,
                        tasks
                            .where((task) => selected.contains(task.id))
                            .toList(),
                      ),
                    );
                  }
                },
          child: Text(text('احفظ كقالب', 'Save as template')),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final operation in [
              ('priority', text('غيّر الأولوية', 'Set priority')),
              ('date', text('انقل التاريخ', 'Move date')),
              ('categoryId', text('غيّر الفئة', 'Set category')),
              ('projectId', text('انقل المشروع', 'Move project')),
              ('listType', text('أرشفة المحدد', 'Archive selected')),
            ])
              OutlinedButton(
                onPressed: busy || selected.isEmpty
                    ? null
                    : () => _bulkEdit(operation.$1),
                child: Text(operation.$2),
              ),
          ],
        ),
        OutlinedButton(
          onPressed: busy || selected.isEmpty
              ? null
              : () => _run((account) async {
                  final failed = <String>{};
                  var saved = 0;
                  for (final id in selected.toList()) {
                    try {
                      await TrashService(db).move(account, 'tasks', id);
                      if (!mounted || uid != account) return;
                      await TasksController().cancelDeletedTaskReminders(id);
                      saved++;
                    } catch (_) {
                      failed.add(id);
                    }
                  }
                  if (!mounted || uid != account) return;
                  setState(() {
                    selected
                      ..clear()
                      ..addAll(failed);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${text('اتنقل', 'Moved')}: $saved • ${text('تحتاج إعادة محاولة', 'Need retry')}: ${failed.length}',
                      ),
                    ),
                  );
                }),
          child: Text(
            text('انقل المحدد لسلة المحذوفات', 'Move selected to trash'),
          ),
        ),
        for (final template in templates.value ?? <Map<String, dynamic>>[])
          Card(
            child: ExpansionTile(
              title: Text(template['name'] as String),
              children: [
                for (final item in template['items'] as List)
                  ListTile(
                    title: Text(
                      ((item as Map)['title'] ?? item['data']?['title'] ?? '')
                          .toString(),
                    ),
                  ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _applyTemplate(template['id'] as String),
                  child: Text(
                    text('أضف المهام بعد المعاينة', 'Add these tasks'),
                  ),
                ),
              ],
            ),
          ),
        Text(
          text(
            'التكرار ينشئ نسخة مستقلة لليوم وبكرة عند فتح التطبيق. الأيام الفائتة لا تتراكم تلقائيًا.',
            'Recurrence creates separate instances for today and tomorrow when the app opens. Missed days do not accumulate.',
          ),
        ),
        for (final recurrence in recurrences.value ?? <Map<String, dynamic>>[])
          SwitchListTile(
            value: recurrence['enabled'] == true,
            title: Text((recurrence['template'] as Map)['title'] as String),
            subtitle: Text(recurrence['frequency'] as String),
            onChanged: busy
                ? null
                : (value) => _run(
                    (account) => db
                        .collection('users')
                        .doc(account)
                        .collection('taskRecurrences')
                        .doc(recurrence['id'] as String)
                        .update({'enabled': value}),
                  ),
          ),
      ],
    );
  }

  Future<void> _applyTemplate(String id) async {
    final account = uid;
    final date = await showDatePicker(
      context: context,
      initialDate: ref.read(calendarClockProvider),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: text('تاريخ بداية النسخة', 'Copy start date'),
    );
    if (date == null || !mounted || uid != account) return;
    await _run((account) async {
      final request = templateRequests.putIfAbsent(
        id,
        () => db.collection('users').doc().id,
      );
      await service.useTemplate(account, id, request, date);
      templateRequests.remove(id);
    });
  }

  Future<void> _configureRecurrence(TaskModel task, String frequency) async {
    if (busy) return;
    if (frequency == 'skip') {
      await _run((account) => service.skipOccurrence(account, task.id));
      return;
    }
    final account = uid;
    DateTime? end;
    var interval = 1, afterCompletion = false;
    final weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(text('إعداد التكرار', 'Recurrence settings')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (frequency == 'interval') ...[
                  DropdownButtonFormField<int>(
                    initialValue: interval,
                    decoration: InputDecoration(
                      labelText: text('عدد الأيام', 'Number of days'),
                    ),
                    items: [
                      for (final days in [
                        1,
                        2,
                        3,
                        4,
                        5,
                        7,
                        10,
                        14,
                        21,
                        30,
                        60,
                        90,
                        180,
                        365,
                      ])
                        DropdownMenuItem(value: days, child: Text('$days')),
                    ],
                    onChanged: (value) => update(() => interval = value ?? 1),
                  ),
                  SwitchListTile(
                    value: afterCompletion,
                    title: Text(
                      text(
                        'احسب الموعد من الإنجاز أو التخطي',
                        'Anchor to completion or skip',
                      ),
                    ),
                    subtitle: Text(
                      text(
                        'بدون الاختيار: من الموعد الأصلي. بعد الإنجاز: نسخة واحدة عند اكتمال السابقة.',
                        'Otherwise use the original schedule. Completion mode creates one successor after the previous copy finishes.',
                      ),
                    ),
                    onChanged: (value) => update(() => afterCompletion = value),
                  ),
                ],
                if (frequency == 'daily')
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(
                            DateFormat.E(
                              Localizations.localeOf(dialog).languageCode,
                            ).format(DateTime(2026, 6, day)),
                          ),
                          selected: weekdays.contains(day),
                          onSelected: (checked) => update(() {
                            if (checked) {
                              weekdays.add(day);
                            } else {
                              weekdays.remove(day);
                            }
                          }),
                        ),
                    ],
                  ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: dialog,
                      initialDate:
                          end ??
                          (task.date.isAfter(ref.read(calendarClockProvider))
                              ? calendarDay(task.date)
                              : ref.read(calendarClockProvider)),
                      firstDate: calendarDay(task.date),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && dialog.mounted) {
                      update(() => end = date);
                    }
                  },
                  child: Text(
                    end == null
                        ? text(
                            'اختار تاريخ نهاية (اختياري)',
                            'Choose end date (optional)',
                          )
                        : DateFormat.yMd().format(end!),
                  ),
                ),
                if (end != null)
                  TextButton(
                    onPressed: () => update(() => end = null),
                    child: Text(text('بدون نهاية', 'No end date')),
                  ),
                Text(
                  text(
                    'النسخ الفائتة لا تتراكم. يوم ٣١ ينتقل لآخر يوم في الشهر القصير.',
                    'Missed copies do not accumulate. Day 31 uses the last day of a shorter month.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(text('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: weekdays.isEmpty
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: Text(text('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted || uid != account) return;
    await _run((account) async {
      await service.saveRecurrence(
        account,
        task,
        frequency,
        end: end,
        weekdays: weekdays.toList()..sort(),
        intervalDays: interval,
        afterCompletion: afterCompletion,
      );
      await service.materialize(account, ref.read(calendarClockProvider));
    });
  }

  Future<void> _snooze(Map<String, dynamic> reminder, int minutes) async {
    final account = uid;
    var duration = Duration(minutes: minutes);
    if (minutes == 0) {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: calendarDay(now),
        lastDate: calendarDay(now, 30),
      );
      if (date == null || !mounted || uid != account) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time == null || !mounted || uid != account) return;
      duration = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).difference(DateTime.now());
      if (duration <= Duration.zero) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text('اختار وقت في المستقبل', 'Choose a future time'),
            ),
          ),
        );
        return;
      }
    }
    await _run((_) async {
      await NotificationInitService.platformSender.snooze(
        reminder['id'] as int,
        duration,
      );
      await _loadReminders();
    });
  }

  Future<void> _bulkEdit(String field) async {
    if (busy || selected.isEmpty) return;
    final labels = AppLocalizations.of(context);
    Object? value;
    if (field == 'date') {
      value = await showDatePicker(
        context: context,
        initialDate: ref.read(calendarClockProvider),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (value is DateTime) value = Timestamp.fromDate(value);
    } else if (field == 'listType') {
      value = 'reference';
    } else {
      final choices = field == 'priority'
          ? {
              'high': text('عالية', 'High'),
              'medium': text('متوسطة', 'Medium'),
              'low': text('منخفضة', 'Low'),
            }
          : field == 'categoryId'
          ? {
              for (final category in ref.read(categoriesProvider).value ?? [])
                category.id: category.isDefault
                    ? labels.tr(category.nameKey)
                    : category.nameKey,
            }
          : {
              for (final project in await ref.read(
                productivityCollectionProvider('paraProjects').future,
              ))
                project['id'] as String: project['title'] as String,
            };
      if (!mounted) return;
      value = await showDialog<String>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(text('اختار القيمة', 'Choose a value')),
          children: [
            for (final choice in choices.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, choice.key),
                child: Text(choice.value),
              ),
          ],
        ),
      );
    }
    if (value == null) return;
    await _run((account) async {
      final failed = <String>[];
      for (final id in selected.toList()) {
        try {
          await db.runTransaction((tx) async {
            final target = db
                    .collection('users')
                    .doc(account)
                    .collection('tasks')
                    .doc(id),
                source = await tx.get(target);
            if (!source.exists || source.data()?['locked'] == true) {
              throw StateError('Task unavailable');
            }
            if (field == 'projectId') {
              final project = await tx.get(
                db
                    .collection('users')
                    .doc(account)
                    .collection('paraProjects')
                    .doc(value as String),
              );
              if (!project.exists ||
                  project.data()?['deletionPending'] == true) {
                throw StateError('Project unavailable');
              }
            }
            tx.update(target, {field: value});
          });
          selected.remove(id);
        } catch (_) {
          failed.add(id);
        }
      }
      if (mounted && uid == account) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failed.isEmpty
                  ? text('تم حفظ التعديلات', 'Changes saved')
                  : text(
                      '${failed.length} عناصر لم تُحفظ وتظل محددة لإعادة المحاولة',
                      '${failed.length} items failed and remain selected for retry',
                    ),
            ),
          ),
        );
      }
    });
  }

  Widget _data() {
    final trash = ref.watch(productivityCollectionProvider('trash'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        ListTile(
          leading: const Icon(Icons.sync),
          title: Text(
            text('اعرض عمليات المزامنة', 'View synchronization outbox'),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OutboxPage()),
          ),
        ),
        Text(
          text(
            'ملفات محلية مجانية. الاستيراد لنفس الحساب، ويتخطى السجلات الموجودة والنقاط والتكليفات الجماعية.',
            'Free local files. Import accepts this account and skips existing IDs, protected rewards and group assignments.',
          ),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => _run((account) async {
                  final data = await BackupService(db).export(account);
                  await _saveFile(
                    data,
                    'Focusly-${CompletionLedger.dateKey(DateTime.now())}.json',
                    'application/json',
                  );
                }),
          icon: const Icon(Icons.download),
          label: Text(text('تصدير نسخة JSON', 'Export JSON backup')),
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => _run((account) async {
                  final file = await openFile(
                    acceptedTypeGroups: [
                      const XTypeGroup(
                        label: 'JSON',
                        extensions: ['json'],
                        mimeTypes: ['application/json'],
                        uniformTypeIdentifiers: ['public.json'],
                      ),
                    ],
                  );
                  if (file == null) return;
                  final preview = BackupService.preview(
                    await file.readAsString(),
                    account,
                  );
                  if (!mounted || uid != account) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: Text(text('معاينة الاستيراد', 'Import preview')),
                      content: Text(
                        '${text('سجلات قابلة للاستيراد', 'Eligible records')}: ${preview.records.length}\n${text('سجلات محمية أو متكررة', 'Protected or duplicate records')}: ${preview.skipped + preview.duplicates}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(text('إلغاء', 'Cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(text('ابدأ الاستيراد', 'Import')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final count = await BackupService(
                    db,
                  ).import(account, preview);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${text('تم استيراد', 'Imported')} $count',
                        ),
                      ),
                    );
                  }
                }),
          icon: const Icon(Icons.upload_file),
          label: Text(text('استيراد مع معاينة', 'Import with preview')),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => _run((account) async {
                  final records = await readFirestorePages(
                    db
                        .collection('users')
                        .doc(account)
                        .collection(csvCollection),
                  );
                  final data = BackupService.csv(
                    records
                        .map((doc) => {'id': doc.id, ...doc.data()})
                        .toList(),
                    switch (csvCollection) {
                      'bodyMetrics' => [
                        'id',
                        'date',
                        'weight',
                        'bpSystolic',
                        'bpDiastolic',
                        'pulse',
                        'notes',
                      ],
                      'checkins' => [
                        'id',
                        'date',
                        'energy',
                        'mood',
                        'sleep',
                        'water',
                      ],
                      'habitLogs' => [
                        'id',
                        'habitId',
                        'date',
                        'completed',
                        'retrospective',
                      ],
                      'pomodoroLogs' => [
                        'id',
                        'date',
                        'taskTitle',
                        'durationSeconds',
                        'partial',
                      ],
                      _ => [
                        'id',
                        'title',
                        'date',
                        'done',
                        'doneAt',
                        'priority',
                      ],
                    },
                  );
                  await _saveFile(
                    data,
                    'Focusly-$csvCollection.csv',
                    'text/csv',
                  );
                }),
          child: Text(text('تصدير CSV', 'Export CSV')),
        ),
        DropdownButton<String>(
          value: csvCollection,
          isExpanded: true,
          items:
              ['tasks', 'bodyMetrics', 'checkins', 'habitLogs', 'pomodoroLogs']
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(
                        moduleLabel(
                          name,
                          Localizations.localeOf(context).languageCode == 'ar',
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: busy
              ? null
              : (value) => setState(() => csvCollection = value!),
        ),
        const Divider(),
        Text(
          text(
            'سلة المحذوفات — الاسترجاع يحافظ على هوية العنصر',
            'Trash — restore keeps the original ID',
          ),
        ),
        for (final item in trash.value ?? <Map<String, dynamic>>[])
          ListTile(
            title: Text(
              ((item['data'] as Map)['title'] ??
                      (item['data'] as Map)['text'] ??
                      item['originalId'])
                  .toString(),
            ),
            subtitle: Text(item['collection'] as String),
            trailing: IconButton(
              tooltip: text('استرجاع', 'Restore'),
              icon: const Icon(Icons.restore),
              onPressed: busy
                  ? null
                  : () => _run(
                      (account) => TrashService(
                        db,
                      ).restore(account, item['id'] as String),
                    ),
            ),
          ),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: Text(
                        text(
                          'تفريغ السلة نهائيًا؟',
                          'Empty trash permanently?',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(text('إلغاء', 'Cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(text('حذف نهائي', 'Delete permanently')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _run((account) => TrashService(db).purge(account));
                  }
                },
          child: Text(text('تفريغ سلة المحذوفات', 'Empty trash')),
        ),
      ],
    );
  }

  Widget _reminders() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
    children: [
      SwitchListTile(
        value: notificationSettings['enabled'] != false,
        title: Text(text('تفعيل التذكيرات', 'Enable reminders')),
        onChanged: (value) => _run((account) async {
          notificationSettings['enabled'] = value;
          await NotificationInitService.platformSender.updateSettings(
            account,
            notificationSettings,
          );
          if (!value) {
            await NotificationInitService.platformSender
                .cancelAllNotifications();
          }
          await _loadReminders();
        }),
      ),
      SwitchListTile(
        value: notificationSettings['contactReminders'] == true,
        title: Text(
          text(
            'تذكير بالتواصل مع العلاقات — اختياري',
            'Relationship reminders — optional',
          ),
        ),
        onChanged: busy
            ? null
            : (value) => _run((account) async {
                notificationSettings['contactReminders'] = value;
                await NotificationInitService.platformSender.updateSettings(
                  account,
                  notificationSettings,
                );
                final contacts = await ref.read(contactsStreamProvider.future);
                await ContactReminderService.refresh(
                  account,
                  contacts,
                  enabled: value,
                );
                await _loadReminders();
              }),
      ),
      SwitchListTile(
        value: notificationSettings['quietEnabled'] == true,
        title: Text(text('ساعات هدوء', 'Quiet hours')),
        onChanged: (value) => _run((account) async {
          notificationSettings['quietEnabled'] = value;
          await NotificationInitService.platformSender.updateSettings(
            account,
            notificationSettings,
          );
          await _loadReminders();
        }),
      ),
      for (final field in ['quietStart', 'quietEnd'])
        ListTile(
          title: Text(
            field == 'quietStart'
                ? text('بداية الهدوء', 'Quiet starts')
                : text('نهاية الهدوء', 'Quiet ends'),
          ),
          trailing: DropdownButton<int>(
            value:
                (notificationSettings[field] as int?) ??
                (field == 'quietStart' ? 22 : 7),
            items: [
              for (var hour = 0; hour < 24; hour++)
                DropdownMenuItem(
                  value: hour,
                  child: Text('${hour.toString().padLeft(2, '0')}:00'),
                ),
            ],
            onChanged: (value) => _run((account) async {
              notificationSettings[field] = value;
              await NotificationInitService.platformSender.updateSettings(
                account,
                notificationSettings,
              );
            }),
          ),
        ),
      Text(
        text(
          'Android يدعم تكرار العادة يوميًا. Windows يجدول المواعيد لدى النظام. الويب يحتاج التبويب مفتوحًا. «مجدول» لا يثبت أن الجهاز عرض التنبيه.',
          'Android supports daily habit recurrence. Windows registers reminders with the OS. Web reminders need an open tab. Scheduled does not prove delivery.',
        ),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => _run(
                (_) => NotificationInitService.sendInstantTestNotification(),
              ),
        child: Text(text('اختبار تنبيه', 'Test notification')),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => _run((_) async {
                final granted = await NotificationInitService.platformSender
                    .requestPermissions();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? text(
                              'التصريح متاح لدى النظام. إعدادات الهدوء قد تمنع العرض.',
                              'OS permission is available. Quiet settings may suppress display.',
                            )
                          : text(
                              'التصريح غير متاح؛ راجع إعدادات التنبيهات في النظام.',
                              'Permission is unavailable; check OS notification settings.',
                            ),
                    ),
                  ),
                );
              }),
        child: Text(text('تحقق من تصريح النظام', 'Check OS permission')),
      ),
      OutlinedButton(
        onPressed: busy ? null : _loadReminders,
        child: Text(text('تحديث المواعيد', 'Refresh upcoming reminders')),
      ),
      for (final reminder in reminders)
        ListTile(
          title: Text(reminder['title'] as String),
          subtitle: Text('${reminder['body']}\n${reminder['date']}'),
          trailing: PopupMenuButton<int>(
            onSelected: (minutes) => _snooze(reminder, minutes),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Text(text('وقت مخصص', 'Custom time')),
              ),
              for (final minutes in [10, 30, 60])
                PopupMenuItem(
                  value: minutes,
                  child: Text(
                    '${text('تأجيل', 'Snooze')} $minutes ${text('دقيقة', 'min')}',
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
