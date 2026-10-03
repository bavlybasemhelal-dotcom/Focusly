import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../data/firestore_provider.dart';
import '../../features/settings/privacy_policy_page.dart';
import '../../features/settings/terms_of_service_page.dart';

const currentTermsVersion = '2026-10-03';
final termsConsentProvider = StreamProvider.autoDispose<bool>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.data()?['termsVersion'] == currentTermsVersion,
      );
});

class TermsConsentPage extends ConsumerStatefulWidget {
  const TermsConsentPage({super.key});
  @override
  ConsumerState<TermsConsentPage> createState() => _TermsConsentPageState();
}

class _TermsConsentPageState extends ConsumerState<TermsConsentPage> {
  bool agreed = false, busy = false;
  String? error;
  String text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  Future<void> save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || !agreed || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(firestoreProvider).collection('users').doc(uid).update({
        'termsVersion': currentTermsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == uid) {
        setState(
          () => error = text(
            'تعذر حفظ الموافقة. جرّب مرة أخرى.',
            'Could not save consent. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              text('أهلًا بيك في Focusly', 'Welcome to Focusly'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              text(
                'راجع سياسة الخصوصية والشروط قبل متابعة استخدام حسابك.',
                'Review the privacy policy and terms before continuing.',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
              child: Text(text('سياسة الخصوصية', 'Privacy policy')),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              ),
              child: Text(text('شروط الاستخدام', 'Terms of service')),
            ),
            CheckboxListTile(
              value: agreed,
              onChanged: busy
                  ? null
                  : (value) => setState(() => agreed = value == true),
              title: Text(
                text(
                  'قرأت الشروط والسياسة وأوافق عليها',
                  'I have read and accept the terms and privacy policy',
                ),
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: agreed && !busy ? save : null,
              child: Text(text('متابعة', 'Continue')),
            ),
            TextButton(
              onPressed: busy ? null : () => logoutAndClearSession(ref),
              child: Text(text('تسجيل الخروج', 'Sign out')),
            ),
          ],
        ),
      ),
    ),
  );
}
