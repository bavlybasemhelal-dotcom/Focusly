import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/data/pending_operations.dart';
import '../../core/data/pending_operations_processor.dart';
import '../../core/data/firestore_provider.dart';

class OutboxPage extends ConsumerStatefulWidget {
  const OutboxPage({super.key, this.onRetry});
  final Future<void> Function()? onRetry;
  @override
  ConsumerState<OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends ConsumerState<OutboxPage> {
  bool busy = false;
  Future<void> retry() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || busy) return;
    setState(() => busy = true);
    try {
      if (widget.onRetry != null) {
        await widget.onRetry!();
      } else {
        await PendingOperationsProcessor.drain(
          ref.read(firestoreProvider),
          uid,
          manual: true,
          stillCurrent: () => mounted && ref.read(currentUserIdProvider) == uid,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'عمليات المزامنة' : 'Synchronization outbox'),
      ),
      body: FutureBuilder(
        key: ValueKey(uid),
        future: uid == null
            ? Future.value(<Map<String, dynamic>>[])
            : PendingOperations.list(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                ar
                    ? 'تعذر تحميل العمليات المحفوظة'
                    : 'Could not read saved operations',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                ar
                    ? 'دي آثار محفوظة على جهازك تخص الحساب الحالي. المحاولة تستخدم نفس الهوية، فلا تتكرر المكافأة. السجلات المحفوظة سحابيًا تظهر في أقسامها.'
                    : 'These saved effects belong to this account. Retries use the same identity and cannot duplicate rewards. Cloud records appear in their modules.',
              ),
              if (snapshot.data!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    ar ? 'لا توجد عمليات معلقة' : 'No pending operations',
                  ),
                ),
              for (final job in snapshot.data!)
                ListTile(
                  leading: Icon(
                    (job['attempts'] as num) >= 5
                        ? Icons.error_outline
                        : Icons.schedule,
                  ),
                  title: Text(
                    (job['payload'] as Map)['label'] as String? ??
                        (job['payload'] as Map)['taskTitle'] as String? ??
                        (ar ? 'حفظ أثر الإنجاز' : 'Save completion effect'),
                  ),
                  subtitle: Text(
                    '${(job['attempts'] as num) >= 5 ? (ar ? 'تعذر الحفظ؛ تحتاج إعادة محاولة' : 'Failed; retry needed') : (ar ? 'بانتظار المزامنة' : 'Awaiting synchronization')} • ${job['queuedAt']}',
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : retry,
                child: Text(ar ? 'أعد المحاولة' : 'Retry'),
              ),
            ],
          );
        },
      ),
    );
  }
}
