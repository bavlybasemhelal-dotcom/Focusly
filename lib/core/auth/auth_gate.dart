import 'terms_consent_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../account_deletion/deletion_checkpoint.dart';
import '../account_deletion/widgets/resume_deletion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/home_screen.dart';
import '../../screens/login_screen.dart';
import '../localization/app_localizations.dart';
import 'auth_provider.dart';
import 'user_profile_service.dart';
import '../data/session_coordinator.dart';

final provisionedProfileProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final document = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final deletion = await FirebaseFirestore.instance
      .collection('accountDeletions')
      .doc(user.uid)
      .get();
  if (deletion.exists ||
      document.data()?['deletionPending'] == true ||
      await DeletionCheckpoint.pending(user.uid)) {
    return false;
  }
  await UserProfileService().ensureUserProfileDocument(user: user);
  return true;
});

/// Keeps private screens behind both authentication and successful provisioning.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const LoginScreen();
    return ref
        .watch(provisionedProfileProvider)
        .when(
          data: (ready) => ready
              ? ref
                    .watch(termsConsentProvider)
                    .when(
                      data: (accepted) => accepted
                          ? const SessionCoordinator(child: HomeScreen())
                          : const TermsConsentPage(),
                      loading: () => const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => Scaffold(
                        body: Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(termsConsentProvider),
                            child: Text(context.tr('retry')),
                          ),
                        ),
                      ),
                    )
              : const ResumeDeletionPage(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('save_failed')),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(provisionedProfileProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('retry')),
                  ),
                  TextButton(
                    onPressed: () => logoutAndClearSession(ref),
                    child: Text(context.tr('logout')),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
