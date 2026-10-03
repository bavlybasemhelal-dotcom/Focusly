import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import 'providers/groups_provider.dart';
import 'services/group_management_service.dart';

class GroupManagementPage extends ConsumerStatefulWidget {
  const GroupManagementPage({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupManagementPage> createState() =>
      _GroupManagementPageState();
}

class _GroupManagementPageState extends ConsumerState<GroupManagementPage> {
  bool saving = false;
  String? error;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  Future<void> run(
    Future<void> Function(GroupManagementService service, String uid) action,
  ) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await action(GroupManagementService(ref.read(firestoreProvider)), uid);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'تعذر حفظ التغيير. تأكد من الصلاحيات واتصالك.',
            'Could not save. Check your permissions and connection.',
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
    final group = ref.watch(groupDetailStreamProvider(widget.groupId)).value;
    final members = ref.watch(groupMembersStreamProvider(widget.groupId));
    final owner = group?.createdBy == uid;
    final root = ref
        .watch(firestoreProvider)
        .collection('groups')
        .doc(widget.groupId);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('إدارة الجروب وسجل القرارات', 'Group management & decisions'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(
              'المالك ينقل الملكية ويغيّر الأدوار والدعوة. الأدمن يدير التكليفات والتحديات. المشرف يراجع طلبات العضوية فقط.',
              'The owner manages ownership, roles and invitations. Admins manage assignments and challenges. Moderators review membership requests.',
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (saving) const LinearProgressIndicator(),
          if (owner)
            FilledButton(
              onPressed: saving
                  ? null
                  : () => run((service, actor) async {
                      await service.rotateInvite(widget.groupId, actor);
                    }),
              child: Text(
                t(
                  'تغيير كود الدعوة وإبطال القديم',
                  'Rotate invitation & revoke old code',
                ),
              ),
            ),
          members.when(
            data: (list) => Column(
              children: [
                for (final member in list.where((item) => item.isApproved))
                  Card(
                    child: ListTile(
                      title: Text(member.name),
                      subtitle: Text(
                        member.uid == group?.createdBy
                            ? t('المالك', 'Owner')
                            : member.role,
                      ),
                      trailing: owner && member.uid != uid
                          ? PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'owner') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialog) => AlertDialog(
                                      title: Text(
                                        t(
                                          'نقل ملكية الجروب',
                                          'Transfer ownership',
                                        ),
                                      ),
                                      content: Text(
                                        t(
                                          'هتنتقل صلاحيات المالك لهذا العضو. ستظل أدمن.',
                                          'This member becomes owner. You remain an admin.',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, false),
                                          child: Text(t('إلغاء', 'Cancel')),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, true),
                                          child: Text(
                                            t('نقل الملكية', 'Transfer'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await run(
                                      (service, actor) => service.transfer(
                                        widget.groupId,
                                        actor,
                                        member.uid,
                                      ),
                                    );
                                  }
                                } else {
                                  await run(
                                    (service, actor) => service.setRole(
                                      widget.groupId,
                                      actor,
                                      member.uid,
                                      action,
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                for (final role in [
                                  ('member', t('عضو', 'Member')),
                                  ('moderator', t('مشرف', 'Moderator')),
                                  ('admin', t('أدمن', 'Admin')),
                                  (
                                    'owner',
                                    t('نقل الملكية', 'Transfer ownership'),
                                  ),
                                ])
                                  PopupMenuItem(
                                    value: role.$1,
                                    child: Text(role.$2),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) =>
                Text(t('تعذر تحميل الأعضاء', 'Could not load members')),
          ),
          Text(t('آخر القرارات', 'Recent decisions')),
          StreamBuilder(
            stream: root
                .collection('audit')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(t('تعذر تحميل السجل', 'Could not load audit log'));
              }
              return Column(
                children: [
                  for (final doc in snapshot.data?.docs ?? [])
                    ListTile(
                      title: Text(doc.data()['action'].toString()),
                      subtitle: Text(
                        '${doc.data()['actorUid']} · ${doc.data()['createdAt']}',
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
