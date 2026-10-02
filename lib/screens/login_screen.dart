import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/auth/google_auth_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _isPasswordObscured = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates inputs and handles Firebase email/password authentication
  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Navigate to Home on successful sign-in
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
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
        _errorMessage = context.tr('login_failed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Initiates interactive Google Sign-In, signs in via Firebase Auth,
  /// provisions profile if new user, and navigates to HomeScreen on success.
  Future<void> _handleGoogleSignIn() async {
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
        // Navigate to Home on successful sign-in
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
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
      debugPrint('[LoginScreen] Google sign-in unexpected error: $e\n$stack');
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

  /// Maps Firebase error codes to friendly, actionable messages
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return context.tr('login_failed');
      case 'invalid-email':
        return context.tr('email_invalid');
      case 'user-disabled':
        return context.tr('user_disabled');
      case 'too-many-requests':
        return context.tr('too_many_requests');
      default:
        return context.tr('login_failed');
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
          // 2. MAIN CENTERED LOGIN CONTENT
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
                      // Centered 3D Focusly Logo with Dynamic Aura Glow
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? AppColors.cyanElectric.withValues(alpha: 0.4)
                                  : const Color(0xFF2563EB).withValues(alpha: 0.22),
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
                                size: 44,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Centered Headline
                      Text(
                        context.tr('welcome_back'),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                          letterSpacing: -0.7,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Centered Subtitle
                      Text(
                        context.tr('login_subtitle'),
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Email Form Field
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
                          final emailRegex =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return context.tr('email_invalid');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password Form Field with Show/Hide Toggle
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
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Remember Me & Forgot Password Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? false;
                                    });
                                  },
                                  activeColor: brandPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rememberMe = !_rememberMe;
                                  });
                                },
                                child: Text(
                                  context.tr('remember_me'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('coming_soon')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('forgot_password'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

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

                      // Full-width Gradient Primary Log In Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: (_isLoading || _isGoogleLoading)
                              ? null
                              : [
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
                          onPressed: (_isLoading || _isGoogleLoading)
                              ? null
                              : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
                            disabledForegroundColor: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: isDark ? const Color(0xFF060B24) : Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  context.tr('log_in'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: (_isLoading || _isGoogleLoading)
                                        ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                                        : (isDark ? const Color(0xFF060B24) : Colors.white),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
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
                                    color: const Color(0xFF2E6FF2).withValues(alpha: 0.05),
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

                      // Footer Signup Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('dont_have_account'),
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
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('sign_up'),
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
              gradient: RadialGradient(
                colors: [cyanGlow, Colors.transparent],
              ),
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
              gradient: RadialGradient(
                colors: [greenGlow, Colors.transparent],
              ),
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
            style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: secondaryTextColor.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(
                icon,
                color: brandPrimary,
                size: 20,
              ),
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
                borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.errorRed, width: 1.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
