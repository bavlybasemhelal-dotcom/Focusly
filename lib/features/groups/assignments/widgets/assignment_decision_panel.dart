import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/data/firestore_provider.dart';

class AssignmentDecisionPanel extends ConsumerStatefulWidget {
  const AssignmentDecisionPanel({
    super.key,
    required this.groupId,
    required this.assignmentId,
  });
  final String groupId, assignmentId;
  @override
  ConsumerState<AssignmentDecisionPanel> createState() =>
      _AssignmentDecisionPanelState();
}

class _AssignmentDecisionPanelState
    extends ConsumerState<AssignmentDecisionPanel> {
  bool saving = false;
  String? error;
  final reason = TextEditingController();
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save(String decision) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final db = ref.read(firestoreProvider);
      final target = db
          .collection('groups')
          .doc(widget.groupId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('completions')
          .doc(uid);
      await db.runTransaction((transaction) async {
        final previous = await transaction.get(target);
        if (!previous.exists) throw StateError('No assignment for this member');
        if (decision == 'rejected' &&
            ((previous.data()?['currentCount'] as num?)?.toInt() ?? 0) > 0) {
          throw StateError('Progress already recorded');
        }
        transaction.update(target, {
          'decision': decision,
          'delayReason': reason.text.trim(),
          'decisionAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'تعذر حفظ القرار. التكليف المكتمل أو اللي بدأته لا يمكن رفضه.',
            'Could not save. Started or completed assignments cannot be rejected.',
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
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref
          .watch(firestoreProvider)
          .collection('groups')
          .doc(widget.groupId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('completions')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data()!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'قراري في التكليف: ${data['decision'] ?? 'offered'}',
                    'My assignment decision: ${data['decision'] ?? 'offered'}',
                  ),
                ),
                TextField(
                  controller: reason,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: t(
                      'سبب تأخير أو ملاحظة للأدمن',
                      'Delay reason or note to admin',
                    ),
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: saving ? null : () => save('accepted'),
                      child: Text(
                        t('قبول وحفظ الملاحظة', 'Accept & save note'),
                      ),
                    ),
                    TextButton(
                      onPressed: saving ? null : () => save('rejected'),
                      child: Text(t('رفض', 'Reject')),
                    ),
                  ],
                ),
                if (data['delayReason'] is String &&
                    (data['delayReason'] as String).isNotEmpty)
                  Text(data['delayReason'] as String),
              ],
            ),
          ),
        );
      },
    );
  }
}
