import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _bioController;

  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    String initialName = '';
    String initialEmail = '';

    try {
      final user = FirebaseAuth.instance.currentUser;
      initialName = user?.displayName ?? '';
      initialEmail = user?.email ?? '';
    } catch (_) {}

    _nameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: initialEmail);
    _phoneController = TextEditingController();
    _jobTitleController = TextEditingController();
    _bioController = TextEditingController();

    _loadUserProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Loads extended user profile fields (phone, jobTitle, bio) from Firestore
  Future<void> _loadUserProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              if (data['name'] != null && _nameController.text.isEmpty) {
                _nameController.text = data['name'].toString();
              }
              if (data['phone'] != null) {
                _phoneController.text = data['phone'].toString();
              }
              if (data['jobTitle'] != null) {
                _jobTitleController.text = data['jobTitle'].toString();
              }
              if (data['bio'] != null) {
                _bioController.text = data['bio'].toString();
              }
            });
          }
        }
      }
    } catch (_) {
      // Safe fallback if offline or during testing
    }
  }

  /// Saves updated profile data to Firebase Auth and Firestore
  Future<void> _handleSaveProfile() async {
    setState(() {
      _statusMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      final newJobTitle = _jobTitleController.text.trim();
      final newBio = _bioController.text.trim();

      if (user != null) {
        // 1. Update Firebase Auth displayName
        await user.updateDisplayName(newName);

        // 2. Update Firestore profile document
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'name': newName,
              'email': user.email,
              'phone': newPhone,
              'jobTitle': newJobTitle,
              'bio': newBio,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = context.tr('profile_updated_success');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = context.tr('profile_update_failed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    String initialLetter = 'F';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (_nameController.text.trim().isNotEmpty) {
        initialLetter = _nameController.text.trim().substring(0, 1).toUpperCase();
      } else if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
        initialLetter = user.displayName!.substring(0, 1).toUpperCase();
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('profile'),
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
          // Ambient Daylight/Midnight Glow Blooms
          _buildAmbientGlowBlooms(isDark),

          // Main Form Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // -----------------------------------------------------------
                    // 1. AVATAR WITH CAMERA OVERLAY BADGE
                    // -----------------------------------------------------------
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF0F1B4C)
                                  : Colors.white,
                              border: Border.all(
                                color: brandPrimary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? AppColors.cyanElectric.withValues(alpha: 0.4)
                                      : const Color(0xFF2563EB).withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initialLetter,
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: brandPrimary,
                                ),
                              ),
                            ),
                          ),

                          // Edit Camera Badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr('avatar_coming_soon')),
                                  ),
                                );
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient(context),
                                  border: Border.all(
                                    color: bgColor,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 17,
                                  color: isDark ? const Color(0xFF060B24) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // -----------------------------------------------------------
                    // 2. PERSONAL INFORMATION SECTION
                    // -----------------------------------------------------------
                    _buildSectionHeader(
                      context.tr('personal_info'),
                      primaryTextColor,
                      const Color(0xFF3B82F6),
                    ),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: _buildCardDecoration(cardBg, borderColor, isDark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name Field
                          _buildFieldLabel(context.tr('full_name'), primaryTextColor),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _nameController,
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

                          // Job Title / Profession Field
                          _buildFieldLabel(context.tr('job_title'), primaryTextColor),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _jobTitleController,
                            hint: context.tr('job_title_hint'),
                            icon: Icons.work_outline_rounded,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            brandPrimary: brandPrimary,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),

                          // Bio / About Me Field (Multiline)
                          _buildFieldLabel(context.tr('bio'), primaryTextColor),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _bioController,
                            hint: context.tr('bio_hint'),
                            icon: Icons.edit_note_rounded,
                            maxLines: 3,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            brandPrimary: brandPrimary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // -----------------------------------------------------------
                    // 3. CONTACT DETAILS SECTION
                    // -----------------------------------------------------------
                    _buildSectionHeader(
                      context.tr('contact_info'),
                      primaryTextColor,
                      const Color(0xFF10B981),
                    ),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: _buildCardDecoration(cardBg, borderColor, isDark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email Field (Read-Only)
                          _buildFieldLabel(context.tr('email'), primaryTextColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                color: secondaryTextColor,
                                size: 20,
                              ),
                              helperText: context.tr('email_read_only_hint'),
                              helperStyle: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? cardBg.withValues(alpha: 0.6)
                                  : const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor, width: 1.2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor, width: 1.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Phone Number Field
                          _buildFieldLabel(context.tr('phone_number'), primaryTextColor),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _phoneController,
                            hint: context.tr('phone_number_hint'),
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            brandPrimary: brandPrimary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inline Status Notification Banner
                    if (_statusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : AppColors.errorRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
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
                              size: 20,
                            ),
                            const SizedBox(width: 10),
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

                    // -----------------------------------------------------------
                    // 4. SAVE CHANGES BUTTON WITH GRADIENT
                    // -----------------------------------------------------------
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
                        onPressed: _isLoading ? null : _handleSaveProfile,
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
                                context.tr('save_changes'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF060B24) : Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 10.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration(Color cardBg, Color borderColor, bool isDark) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  Widget _buildFieldLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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
        filled: true,
        fillColor: isDark ? cardBg : const Color(0xFFFAFCFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
