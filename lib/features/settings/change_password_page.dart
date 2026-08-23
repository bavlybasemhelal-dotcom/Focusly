import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    setState(() {
      _statusMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User session not found.');
      }

      final currentPass = _currentPasswordController.text.trim();
      final newPass = _newPasswordController.text.trim();

      // 1. Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPass,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Update password
      await user.updatePassword(newPass);

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = context.tr('password_updated_success');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = _mapFirebasePasswordError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = context.tr('error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapFirebasePasswordError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return context.tr('reauth_failed');
      case 'weak-password':
        return context.tr('password_min_length');
      case 'requires-recent-login':
        return context.tr('requires_recent_login');
      default:
        return context.tr('reauth_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('change_password'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Glow
          _buildAmbientGlowBlooms(isDark),

          // Form Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Current Password
                    _buildFieldLabel(context.tr('current_password'), primaryTextColor),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      hint: '••••••••••••',
                      isObscured: _obscureCurrent,
                      onToggle: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('password_required');
                        }
                        return null;
                      },
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),

                    // 2. New Password
                    _buildFieldLabel(context.tr('new_password'), primaryTextColor),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      hint: '8+ characters',
                      isObscured: _obscureNew,
                      onToggle: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('password_required');
                        }
                        if (value.length < 8) {
                          return context.tr('password_min_length');
                        }
                        return null;
                      },
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),

                    // 3. Confirm New Password
                    _buildFieldLabel(
                      context.tr('confirm_new_password'),
                      primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hint: '••••••••••••',
                      isObscured: _obscureConfirm,
                      onToggle: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('confirm_password_required');
                        }
                        if (value != _newPasswordController.text) {
                          return context.tr('passwords_not_match');
                        }
                        return null;
                      },
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      brandPrimary: brandPrimary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    // Inline Status Banner
                    if (_statusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : AppColors.errorRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSuccess
                                ? AppColors.accentGreen
                                : AppColors.errorRed,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              color: _isSuccess
                                  ? AppColors.accentGreen
                                  : AppColors.errorRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isSuccess
                                      ? AppColors.accentGreen
                                      : AppColors.errorRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 4. Update Password Button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? AppColors.cyanElectric.withValues(alpha: 0.35)
                                : const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleUpdatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor:
                              isDark ? const Color(0xFF060B24) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: isDark
                                      ? const Color(0xFF060B24)
                                      : Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                context.tr('update_password_btn'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF060B24) : Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isObscured,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isObscured,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: secondaryTextColor.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: brandPrimary,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              isObscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: secondaryTextColor,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: cardBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: brandPrimary, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.14)
        : const Color(0xFF38BDF8).withValues(alpha: 0.18);

    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [cyanGlow, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
