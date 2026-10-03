import '../../core/platform/desktop_bridge.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import '../tasks/models/task_model.dart';
import '../tasks/providers/tasks_provider.dart';
import '../goals/providers/goals_provider.dart';
import 'services/productivity_service.dart';

class TaskLinksPage extends ConsumerStatefulWidget {
  const TaskLinksPage({super.key, required this.task});
  final TaskModel task;
  @override
  ConsumerState<TaskLinksPage> createState() => _TaskLinksPageState();
}

class _TaskLinksPageState extends ConsumerState<TaskLinksPage> {
  final duration = TextEditingController(text: '25');
  final url = TextEditingController();
  final dependencies = <String>{};
  final attachments = <Map<String, String>>[];
  String? goalId;
  String? milestone;
  String? error;
  bool loading = true;
  bool saving = false;
  String text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    duration.dispose();
    url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      final snapshot = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(widget.task.id)
          .get();
      final data = snapshot.data() ?? {};
      if (!mounted || uid != ref.read(currentUserIdProvider)) return;
      duration.text = '${data['estimatedMinutes'] ?? 25}';
      dependencies.addAll(
        (data['dependsOn'] as List?)?.whereType<String>() ?? [],
      );
      attachments.addAll(
        (data['attachments'] as List?)?.map(
              (value) => Map<String, String>.from(value as Map),
            ) ??
            [],
      );
      goalId = data['goalId'] as String?;
      milestone = data['milestoneTitle'] as String?;
    } catch (failure) {
      error = failure.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ProductivityService(ref.read(firestoreProvider)).linkTask(
        uid: uid,
        taskId: widget.task.id,
        dependencies: dependencies.toList(),
        goalId: goalId,
        milestoneTitle: milestone,
        estimatedMinutes: int.tryParse(duration.text) ?? 0,
        attachments: attachments,
      );
      if (mounted && uid == ref.read(currentUserIdProvider)) {
        Navigator.pop(context);
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final goals = ref.watch(goalsStreamProvider).value ?? [];
    final existingGoal = goals.where((goal) => goal.id == goalId).firstOrNull;
    final milestoneTitles =
        existingGoal?.milestones.map((value) => value.title).toSet().toList() ??
        <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextField(
                  controller: duration,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: text(
                      'الوقت التقديري بالدقائق',
                      'Estimated minutes',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  text(
                    'مهمات لازم تخلص قبل المهمة دي — ممنوع الاعتماد الدائري',
                    'Prerequisite tasks — circular dependencies are rejected',
                  ),
                ),
                for (final missing in dependencies.where(
                  (id) => !tasks.any((task) => task.id == id),
                ))
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(
                      text(
                        'مهمة مطلوبة محذوفة؛ استرجعها أو احذف الاعتماد',
                        'A prerequisite is deleted; restore it or remove this dependency',
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: text('احذف الاعتماد', 'Remove dependency'),
                      icon: const Icon(Icons.link_off),
                      onPressed: saving
                          ? null
                          : () => setState(() => dependencies.remove(missing)),
                    ),
                  ),
                for (final task in tasks.where(
                  (task) => task.id != widget.task.id,
                ))
                  CheckboxListTile(
                    title: Text(task.title),
                    value: dependencies.contains(task.id),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              dependencies.add(task.id);
                            } else {
                              dependencies.remove(task.id);
                            }
                          }),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: existingGoal?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: text('هدف مرتبط', 'Linked goal'),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(text('بدون هدف', 'No goal')),
                    ),
                    for (final goal in goals)
                      DropdownMenuItem(value: goal.id, child: Text(goal.title)),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          goalId = value;
                          milestone = null;
                        }),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(goalId),
                  initialValue: milestoneTitles.contains(milestone)
                      ? milestone
                      : null,
                  decoration: InputDecoration(
                    labelText: text('مرحلة مرتبطة', 'Linked milestone'),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(text('بدون مرحلة', 'No milestone')),
                    ),
                    for (final title in milestoneTitles)
                      DropdownMenuItem(value: title, child: Text(title)),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => milestone = value),
                ),
                const SizedBox(height: 16),
                Text(
                  text(
                    'مرفقات وروابط — الملفات تفضل على جهازك ولا تُرفع للسحابة',
                    'Links and attachments — files remain on your device',
                  ),
                ),
                for (final attachment in attachments)
                  ListTile(
                    title: Text(attachment['name'] ?? attachment['value']!),
                    subtitle: Text(attachment['value']!),
                    onTap: () async {
                      final value = attachment['value']!;
                      if (attachment['kind'] == 'local' &&
                          DesktopBridge.available) {
                        await DesktopBridge.request('openLocalFile', {
                          'path': value,
                        });
                        return;
                      }
                      final uri = attachment['kind'] == 'url'
                          ? Uri.tryParse(value)
                          : Uri.file(value);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    trailing: IconButton(
                      tooltip: text('إزالة الرابط', 'Remove attachment'),
                      icon: const Icon(Icons.close),
                      onPressed: saving
                          ? null
                          : () =>
                                setState(() => attachments.remove(attachment)),
                    ),
                  ),
                TextField(
                  controller: url,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: text('رابط https', 'HTTPS link'),
                  ),
                ),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () {
                          final value = url.text.trim();
                          final uri = Uri.tryParse(value);
                          if (uri == null ||
                              !['https', 'http'].contains(uri.scheme) ||
                              uri.host.isEmpty) {
                            setState(
                              () => error = text(
                                'أدخل رابطًا صحيحًا',
                                'Enter a valid link',
                              ),
                            );
                            return;
                          }
                          setState(() {
                            attachments.add({'kind': 'url', 'value': value});
                            url.clear();
                          });
                        },
                  child: Text(text('إضافة رابط', 'Add link')),
                ),
                if (!kIsWeb || DesktopBridge.available)
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (DesktopBridge.available) {
                              final result = await DesktopBridge.request(
                                'chooseLocalFile',
                              );
                              final path = result['path'] as String?;
                              if (path != null && mounted) {
                                setState(
                                  () => attachments.add({
                                    'kind': 'local',
                                    'value': path,
                                    'name': path.split(RegExp(r'[\/]')).last,
                                  }),
                                );
                              }
                              return;
                            }
                            final file = await openFile();
                            if (file != null && mounted) {
                              setState(
                                () => attachments.add({
                                  'kind': 'local',
                                  'value': file.path,
                                  'name': file.name,
                                }),
                              );
                            }
                          },
                    child: Text(text('ربط ملف محلي', 'Link local file')),
                  ),
                FilledButton(
                  onPressed: saving || widget.task.isGroupAssigned
                      ? null
                      : _save,
                  child: Text(
                    saving
                        ? text('جاري الحفظ', 'Saving')
                        : text('حفظ الروابط', 'Save links'),
                  ),
                ),
                if (widget.task.isGroupAssigned)
                  Text(
                    text(
                      'التكليف الجماعي مقفول للتعديل.',
                      'Group assignments are locked.',
                    ),
                  ),
              ],
            ),
    );
  }
}
