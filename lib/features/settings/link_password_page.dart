import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Adds a password to the existing UID; it never creates another account.
class LinkPasswordPage extends StatefulWidget {
  const LinkPasswordPage({super.key});
  @override
  State<LinkPasswordPage> createState() => _LinkPasswordPageState();
}

class _LinkPasswordPageState extends State<LinkPasswordPage> {
  final password = TextEditingController(), confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (user!.providerData.any(
        (provider) => provider.providerId == 'password',
      )) {
        throw StateError('Password is already linked');
      }
      await user.linkWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: password.text,
        ),
      );
      await user.reload();
      if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'requires-recent-login'
              ? t(
                  'سجّل الدخول من جديد وبعدين جرّب الربط.',
                  'Sign in again before linking a password.',
                )
              : t(
                  'تعذر ربط كلمة السر. بياناتك فضلت كما هي.',
                  'Could not link this password. Your data remains saved.',
                ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'كلمة سر مرتبطة بالفعل أو الجلسة غير متاحة.',
            'A password is already linked or the session is unavailable.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(t('إضافة دخول بكلمة سر', 'Add password sign-in')),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(FirebaseAuth.instance.currentUser?.email ?? ''),
          TextFormField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(labelText: t('كلمة السر', 'Password')),
            validator: (value) => (value?.length ?? 0) < 8
                ? t('٨ أحرف على الأقل', 'At least 8 characters')
                : null,
          ),
          TextFormField(
            controller: confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: t('تأكيد كلمة السر', 'Confirm password'),
            ),
            validator: (value) => value != password.text
                ? t('التأكيد مختلف', 'Passwords do not match')
                : null,
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: saving ? null : save,
            child: saving
                ? const CircularProgressIndicator()
                : Text(t('ربط بنفس الحساب', 'Link to this account')),
          ),
        ],
      ),
    ),
  );
}
