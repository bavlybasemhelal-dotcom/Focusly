import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/auth/google_auth_service.dart';
import '../core/auth/user_profile_service.dart';
import '../core/auth/auth_gate.dart';
import '../core/auth/session_preferences.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  User? _createdUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Handles user account creation in Firebase Auth and profile write to Firestore
  Future<void> _handleSignup() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = context.tr('terms_required');
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 1. Create User in Firebase Authentication
      if (_createdUser == null) {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        _createdUser = userCredential.user;
      }

      final user = _createdUser;
      if (user?.email?.toLowerCase() != email.toLowerCase() ||
          FirebaseAuth.instance.currentUser?.uid != user?.uid) {
        throw StateError(
          'Use the email of the account already created to retry profile setup',
        );
      }
      if (user != null) {
        // 2. Update Display Name
        await user.updateDisplayName(name);

        // 3. Write user profile document in Firestore (users/{uid})
        await UserProfileService().createUserDocument(
          uid: user.uid,
          name: name,
          email: email,
        );
        await UserProfileService().recordTermsConsent(user.uid);
        await SessionPreferences.setRemember(true);
      } else {
        throw StateError('Registration returned no user');
      }

      if (!mounted) return;

      // Navigate to Home on successful account creation
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapFirebaseAuthError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('signup_failed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Initiates interactive Google Sign-In / Sign-Up, signs in via Firebase Auth,
  /// provisions profile if new user, and navigates to HomeScreen on success.
  Future<void> _handleGoogleSignIn() async {
    if (!_agreedToTerms) {
      setState(() => _errorMessage = context.tr('terms_required'));
      return;
    }
    setState(() {
      _errorMessage = null;
      _isGoogleLoading = true;
    });

    try {
      final googleAuthService = GoogleAuthService();
      final result = await googleAuthService.signInWithGoogle();

      if (!mounted) return;

      if (result.isCancelled) {
        // User dismissed the Google account picker - quietly return with no error
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      if (result.isPopupBlocked) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = context.tr('google_popup_blocked');
        });
        return;
      }

      if (result.isAccountExistsWithDifferentCredential) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = context.tr('account_exists_different_credential');
        });
        return;
      }

      if (result.isError) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = context.tr('google_signin_failed');
        });
        return;
      }

      if (result.isSuccess) {
        await UserProfileService().recordTermsConsent(result.user!.uid);
        await SessionPreferences.setRemember(true);
        if (!mounted) return;
        // Navigate to Home on successful sign-in
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthGate(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[SignupScreen] Google sign-in unexpected error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = context.tr('google_signin_failed');
      });
    } finally {
      if (mounted && _isGoogleLoading) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  /// Maps Firebase error codes to friendly messages
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return context.tr('email_already_in_use');
      case 'invalid-email':
        return context.tr('email_invalid');
      case 'weak-password':
        return context.tr('weak_password');
      default:
        return context.tr('signup_failed');
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // -----------------------------------------------------------------
          // 1. AMBIENT BACKGROUND AURORA BLOOMS
          // -----------------------------------------------------------------
          _buildAmbientGlowBlooms(isDark),

          // -----------------------------------------------------------------
          // 2. MAIN CENTERED SIGNUP CONTENT
          // -----------------------------------------------------------------
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Centered 3D Focusly Logo with Dynamic Glow
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? AppColors.cyanElectric.withValues(
                                      alpha: 0.4,
                                    )
                                  : const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.22),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cardBg,
                                border: Border.all(
                                  color: brandPrimary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.track_changes_rounded,
                                color: brandPrimary,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Centered Headline
                      Text(
                        context.tr('create_account'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                          letterSpacing: -0.7,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Centered Subtitle
                      Text(
                        context.tr('signup_subtitle'),
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // 1. Full Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: context.tr('full_name'),
                        hint: context.tr('full_name_hint'),
                        icon: Icons.person_outline_rounded,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        brandPrimary: brandPrimary,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('full_name_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: context.tr('email'),
                        hint: context.tr('email_hint'),
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        brandPrimary: brandPrimary,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('email_required');
                          }
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return context.tr('email_invalid');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Password Field
                      _buildTextField(
                        controller: _passwordController,
                        label: context.tr('password'),
                        hint: context.tr('password_hint'),
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isObscured: _isPasswordObscured,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        brandPrimary: brandPrimary,
                        isDark: isDark,
                        onToggleObscure: () {
                          setState(() {
                            _isPasswordObscured = !_isPasswordObscured;
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
                      ),
                      const SizedBox(height: 16),

                      // 4. Confirm Password Field
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: context.tr('confirm_password'),
                        hint: context.tr('confirm_password_hint'),
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        isObscured: _isConfirmPasswordObscured,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        brandPrimary: brandPrimary,
                        isDark: isDark,
                        onToggleObscure: () {
                          setState(() {
                            _isConfirmPasswordObscured =
                                !_isConfirmPasswordObscured;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('confirm_password_required');
                          }
                          if (value != _passwordController.text) {
                            return context.tr('passwords_dont_match');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Terms & Conditions Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (val) {
                                setState(() {
                                  _agreedToTerms = val ?? false;
                                });
                              },
                              activeColor: brandPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _agreedToTerms = !_agreedToTerms;
                                });
                              },
                              child: Text(
                                context.tr('terms_agreement'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Inline Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.errorRed,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.errorRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.errorRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Full-width Primary Gradient Sign Up Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: (_isLoading || !_agreedToTerms)
                              ? null
                              : AppColors.primaryGradient(context),
                          color: (_isLoading || !_agreedToTerms)
                              ? (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0))
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow:
                              (_isLoading ||
                                  _isGoogleLoading ||
                                  !_agreedToTerms)
                              ? null
                              : [
                                  BoxShadow(
                                    color: isDark
                                        ? AppColors.cyanElectric.withValues(
                                            alpha: 0.35,
                                          )
                                        : const Color(
                                            0xFF2563EB,
                                          ).withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              (_isLoading ||
                                  _isGoogleLoading ||
                                  !_agreedToTerms)
                              ? null
                              : _handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: isDark
                                ? const Color(0xFF060B24)
                                : Colors.white,
                            disabledForegroundColor: isDark
                                ? Colors.white38
                                : const Color(0xFF94A3B8),
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
                                  context.tr('sign_up'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        (_isLoading ||
                                            _isGoogleLoading ||
                                            !_agreedToTerms)
                                        ? (isDark
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8))
                                        : (isDark
                                              ? const Color(0xFF060B24)
                                              : Colors.white),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider "or"
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: borderColor, height: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                            ),
                            child: Text(
                              context.tr('or'),
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: borderColor, height: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Social "Continue with Google" Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: (isDark || _isLoading || _isGoogleLoading)
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2E6FF2,
                                    ).withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: OutlinedButton(
                          onPressed: (_isLoading || _isGoogleLoading)
                              ? null
                              : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isGoogleLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: brandPrimary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'G',
                                          style: TextStyle(
                                            color: Color(0xFF4285F4),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.tr('continue_with_google'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Footer Login Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('already_have_account'),
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('log_in'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.16)
        : const Color(0xFF38BDF8).withValues(alpha: 0.20);
    final greenGlow = isDark
        ? AppColors.accentGreenNeon.withValues(alpha: 0.14)
        : const Color(0xFF34D399).withValues(alpha: 0.18);

    return Stack(
      children: [
        Positioned(
          top: -110,
          right: -110,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [cyanGlow, Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -90,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [greenGlow, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
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
            obscureText: isPassword && isObscured,
            keyboardType: keyboardType,
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: secondaryTextColor.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(icon, color: brandPrimary, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isObscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: secondaryTextColor,
                        size: 20,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
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
                borderSide: const BorderSide(
                  color: AppColors.errorRed,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.errorRed,
                  width: 1.8,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
