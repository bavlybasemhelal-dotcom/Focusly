import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import 'services/productivity_service.dart';

class WorkspaceTemplatesPage extends ConsumerStatefulWidget {
  const WorkspaceTemplatesPage({super.key});
  @override
  ConsumerState<WorkspaceTemplatesPage> createState() =>
      _WorkspaceTemplatesPageState();
}

class _WorkspaceTemplatesPageState
    extends ConsumerState<WorkspaceTemplatesPage> {
  final name = TextEditingController();
  final selected = <String, Map<String, dynamic>>{};
  bool busy = false;
  String text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || busy || selected.isEmpty || name.text.trim().isEmpty) {
      return;
    }
    setState(() => busy = true);
    try {
      await ProductivityService(
        ref.read(firestoreProvider),
      ).saveWorkspaceTemplate(uid, name.text, selected.values.toList());
      if (mounted && ref.read(currentUserIdProvider) == uid) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text(
                'تعذر الحفظ. اختياراتك محفوظة للمحاولة تاني.',
                'Could not save. Your selections remain available to retry.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(text('قالب مشروع أو روتين', 'Project or routine template')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: text('اسم القالب', 'Template name'),
            ),
          ),
          Text(
            text(
              'اختار لحد ٥٠ عنصر. كل نسخة تبدأ بتقدم صفر، وروابط المشروع المختار تنتقل للنسخة الجديدة.',
              'Select up to 50 items. Copies start with zero progress; links to selected projects point to the new copies.',
            ),
          ),
          for (final source in [
            ('paraProjects', text('مشاريع', 'Projects')),
            ('tasks', text('مهام', 'Tasks')),
            ('habits', text('عادات', 'Habits')),
          ])
            if (uid != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref
                    .watch(firestoreProvider)
                    .collection('users')
                    .doc(uid)
                    .collection(source.$1)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) => ExpansionTile(
                  title: Text(source.$2),
                  children: [
                    if (snapshot.hasError)
                      Text(text('تعذر التحميل', 'Could not load')),
                    if (!snapshot.hasData && !snapshot.hasError)
                      const LinearProgressIndicator(),
                    for (final doc
                        in snapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      if (doc.data()['locked'] != true &&
                          doc.data()['assignedByGroupId'] == null)
                        CheckboxListTile(
                          value: selected.containsKey('${source.$1}/${doc.id}'),
                          title: Text(
                            (doc.data()['title'] ?? doc.id).toString(),
                          ),
                          onChanged: busy
                              ? null
                              : (checked) => setState(() {
                                  final key = '${source.$1}/${doc.id}';
                                  if (checked == true && selected.length < 50) {
                                    selected[key] = {
                                      'collection': source.$1,
                                      'id': doc.id,
                                      'data': doc.data(),
                                    };
                                  } else {
                                    selected.remove(key);
                                  }
                                }),
                        ),
                    if ((snapshot.data?.docs.length ?? 0) == 100)
                      Text(
                        text(
                          'تُعرض أول ١٠٠ عنصر لكل قسم لتقليل استهلاك القراءة.',
                          'The first 100 items per module are shown to limit read usage.',
                        ),
                      ),
                  ],
                ),
              ),
          FilledButton(
            onPressed: busy || selected.isEmpty ? null : save,
            child: Text(
              '${text('حفظ القالب', 'Save template')} (${selected.length})',
            ),
          ),
        ],
      ),
    );
  }
}
