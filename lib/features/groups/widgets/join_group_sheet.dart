import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

/// Modal bottom sheet for joining an existing Group via Invite Code.
class JoinGroupSheet extends StatefulWidget {
  const JoinGroupSheet({super.key});

  @override
  State<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<JoinGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final inputCode = _codeController.text.trim().toUpperCase();

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Check user group cap
      final userDocRef = firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      final currentGroupIds = List<String>.from(
        userDoc.data()?['groupIds'] ?? [],
      );

      if (currentGroupIds.length >= GroupModel.maxGroupsPerUser) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.tr('group_cap_reached');
        });
        return;
      }

      final invitation = await firestore
          .collection('invites')
          .doc(inputCode)
          .get();
      if (!invitation.exists) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorMessage = context.tr('group_not_found');
          });
        }
        return;
      }
      final groupId = invitation.data()!['groupId'] as String;

      // 4. Check existing member or pending request
      final memberDocRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid);
      final memberDoc = await memberDocRef.get();

      if (memberDoc.exists) {
        final status = memberDoc.data()?['status'];
        if (status == 'approved') {
          setState(() {
            _isSubmitting = false;
            _errorMessage = context.tr('already_member');
          });
          return;
        } else if (status == 'pending') {
          setState(() {
            _isSubmitting = false;
            _errorMessage = context.tr('already_pending');
          });
          return;
        }
      }

      // 5. Submit pending join request
      final userName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : 'User';

      final pendingMember = GroupMemberModel(
        uid: user.uid,
        name: userName,
        role: 'member',
        status: 'pending',
        requestedAt: DateTime.now(),
      );

      await memberDocRef.set({
        ...pendingMember.toMap(),
        'inviteCode': inputCode,
      });

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('join_request_sent_success'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
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
    final inputBg = isDark ? const Color(0xFF0B1238) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F5);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                context.tr('join_group_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('join_group_subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 20),

              // Invite Code Input
              Text(
                context.tr('invite_code_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'GRP-XXXXXX',
                  hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                  filled: true,
                  fillColor: inputBg,
                  prefixIcon: Icon(
                    Icons.tag_rounded,
                    color: brandPrimary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: brandPrimary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return context.tr('invite_code_required');
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Join Request Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          context.tr('send_join_request_btn'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
