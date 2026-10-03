import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import '../productivity/search_navigation.dart';
import 'services/goals_service.dart';

class GoalSourcesPage extends ConsumerWidget {
  const GoalSourcesPage({super.key, required this.goalId});
  final String goalId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final db = ref.watch(firestoreProvider);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String arabic, String english) => ar ? arabic : english;
    if (uid == null) return const Scaffold();
    final user = db.collection('users').doc(uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('مصادر تقدم الهدف', 'Goal progress sources')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(
              'المرحلة المرتبطة تكتمل عندما تكتمل مهامها. التعديل اليدوي يوقف الاشتقاق لهذه المرحلة حتى تختار إعادته.',
              'Linked milestones finish when their tasks finish. Manual changes pause derivation until you resume it.',
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: user.collection('goals').doc(goalId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(t('تعذر تحميل المصدر', 'Could not load source'));
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final data = snapshot.data!.data() ?? {};
              return Column(
                children: [
                  for (final title
                      in (data['manualMilestones'] as List? ?? [])
                          .whereType<String>())
                    ListTile(
                      title: Text(title),
                      subtitle: Text(t('تعديل يدوي', 'Manual override')),
                      trailing: TextButton(
                        child: Text(t('اعتمد المهام', 'Use linked tasks')),
                        onPressed: () async {
                          try {
                            await GoalsService(
                              firestore: db,
                            ).resumeLinkedMilestone(
                              uid: uid,
                              goalId: goalId,
                              title: title,
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$error')));
                            }
                          }
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: user
                .collection('tasks')
                .where('goalId', isEqualTo: goalId)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(t('تعذر تحميل المهام', 'Could not load tasks'));
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(
                children: [
                  for (final doc in snapshot.data!.docs)
                    ListTile(
                      title: Text(doc.data()['title'] as String? ?? doc.id),
                      subtitle: Text(
                        '${doc.data()['milestoneTitle'] ?? ''} • ${doc.data()['done'] == true ? t('تمت', 'Done') : t('معلقة', 'Pending')}',
                      ),
                      onTap: () => openSearchResult(context, {
                        ...doc.data(),
                        'id': doc.id,
                        'collection': 'tasks',
                      }),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Text(t('سجل التعديلات — أحدث ١٠٠', 'Change history — latest 100')),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: user
                .collection('goalAudit')
                .where('goalId', isEqualTo: goalId)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(t('تعذر تحميل السجل', 'Could not load history'));
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(
                children: [
                  for (final doc in snapshot.data!.docs)
                    ListTile(
                      title: Text(
                        '${doc.data()['milestoneTitle'] ?? ''} • ${doc.data()['source'] ?? ''}',
                      ),
                      subtitle: Text(
                        '${doc.data()['reason'] ?? ''}\n${(doc.data()['createdAt'] as Timestamp?)?.toDate() ?? ''}',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
