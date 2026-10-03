import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import '../account_deletion_service.dart';
import 'reauth_dialog.dart';

class ResumeDeletionPage extends ConsumerStatefulWidget {
  const ResumeDeletionPage({super.key});
  @override
  ConsumerState<ResumeDeletionPage> createState() => _ResumeDeletionPageState();
}

class _ResumeDeletionPageState extends ConsumerState<ResumeDeletionPage> {
  bool busy = false;
  String? error;
  Future<void> resume() async {
    setState(() {
      busy = true;
      error = null;
    });
    final service = AccountDeletionService();
    try {
      await service.deleteCurrentAccount();
      if (mounted) await logoutAndClearSession(ref);
    } on ReauthenticationRequiredException catch (exception) {
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ReauthDialog(exception: exception),
        );
        if (confirmed == true) {
          try {
            await service.finalizeAuthDeletionAfterReauth();
            if (mounted) await logoutAndClearSession(ref);
          } catch (failure) {
            error = failure.toString();
          }
        }
      }
    } catch (failure) {
      error = failure.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever, size: 44),
              Text(
                ar ? 'حذف الحساب لم يكتمل' : 'Account deletion is unfinished',
              ),
              Text(
                ar
                    ? 'يمكنك استكمال الحذف من آخر مرحلة. البيانات المحذوفة لا يمكن استرجاعها.'
                    : 'Resume the interrupted deletion. Erased data cannot be restored.',
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: busy ? null : resume,
                child: Text(ar ? 'استكمال الحذف' : 'Resume deletion'),
              ),
              TextButton(
                onPressed: busy ? null : () => logoutAndClearSession(ref),
                child: Text(ar ? 'تسجيل الخروج' : 'Sign out'),
              ),
              if (busy) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
