import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../account_deletion_service.dart';

/// Modal dialog presented when Firebase Auth requires recent authentication
/// (`requires-recent-login`) before permanently deleting the user account.
class ReauthDialog extends StatefulWidget {
  final ReauthenticationRequiredException exception;

  const ReauthDialog({
    super.key,
    required this.exception,
  });

  @override
  State<ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<ReauthDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reauthWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? widget.exception.email;
    if (email == null || email.isEmpty) {
      setState(() {
        _errorMessage = context.tr('reauth_failed');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use signInWithEmailAndPassword directly to avoid the known FlutterFire
      // Windows threading bug where reauthenticateWithCredential hangs indefinitely.
      // Signing in with the existing email and password updates currentUser's auth token
      // and establishes a fresh recent sign-in timestamp.
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? context.tr('reauth_failed')
            : (e.message ?? context.tr('error'));
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('reauth_failed');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('reauth_failed');
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reauthWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled Google picker
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? context.tr('reauth_failed');
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('reauth_failed');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('reauth_failed');
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final hasPassword = widget.exception.hasPasswordProvider ||
        widget.exception.providerIds.isEmpty;
    final hasGoogle = widget.exception.hasGoogleProvider;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.border(context), width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.errorRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('reauth_required_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('reauth_required_message'),
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Password Field Option
            if (hasPassword) ...[
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  hintText: context.tr('reauth_password_hint'),
                  prefixIcon: const Icon(Icons.password_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.errorRed,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isLoading ? null : _reauthWithPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.tr('reauth_verify_btn'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],

            // Divider if both providers present
            if (hasPassword && hasGoogle) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border(context))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        context.tr('or'),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border(context))),
                  ],
                ),
              ),
            ],

            // Google Sign In Option
            if (hasGoogle) ...[
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _reauthWithGoogle,
                icon: Image.asset(
                  'assets/images/google_logo.png',
                  height: 18,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_circle,
                    size: 18,
                  ),
                ),
                label: Text(context.tr('reauth_google_btn')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            context.tr('cancel'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
