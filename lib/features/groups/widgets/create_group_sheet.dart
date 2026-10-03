import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../group_detail_page.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

/// Modal bottom sheet for creating a new Group in Focusly.
class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedEmoji = '🚀';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _emojiOptions = [
    '🚀',
    '🎯',
    '⚡',
    '🔥',
    '🌟',
    '🏆',
    '💎',
    '🦉',
    '🌱',
    '💻',
    '🎨',
    '👑',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buffer = StringBuffer('GRP-');
    for (int i = 0; i < 12; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
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

    try {
      final firestore = FirebaseFirestore.instance;
      final userDocRef = firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      final currentGroupIds = List<String>.from(
        userDoc.data()?['groupIds'] ?? [],
      );

      // Check max groups per user cap
      if (currentGroupIds.length >= GroupModel.maxGroupsPerUser) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.tr('group_cap_reached');
        });
        return;
      }

      // Generate unique invite code with collision check
      String inviteCode = _generateInviteCode();
      bool isUnique = false;
      int retries = 0;
      while (!isUnique && retries < 5) {
        final existing = await firestore
            .collection('invites')
            .doc(inviteCode)
            .get();
        if (!existing.exists) {
          isUnique = true;
        } else {
          inviteCode = _generateInviteCode();
          retries++;
        }
      }

      if (!isUnique) {
        throw StateError('Could not reserve an invite code; please retry.');
      }
      final now = DateTime.now();
      final currentWeekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday % 7),
      );

      final groupRef = firestore.collection('groups').doc();
      final group = GroupModel(
        id: groupRef.id,
        name: _nameController.text.trim(),
        icon: _selectedEmoji,
        description: _descController.text.trim(),
        inviteCode: inviteCode,
        createdBy: user.uid,
        createdAt: now,
        memberCount: 1,
        maxMembers: GroupModel.defaultMaxMembers,
        status: 'active',
        weekStart: currentWeekStart,
      );

      final creatorName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : 'Admin';

      final member = GroupMemberModel(
        uid: user.uid,
        name: creatorName,
        role: 'admin',
        status: 'approved',
        requestedAt: now,
        joinedAt: now,
        weeklyXP: 0,
      );

      await firestore.runTransaction((batch) async {
        final current = await batch.get(userDocRef);
        final invitation = await batch.get(
          firestore.collection('invites').doc(inviteCode),
        );
        if (invitation.exists) {
          throw StateError('Invite collision; please retry.');
        }
        if ((current.data()?['groupIds'] as List? ?? []).length >=
            GroupModel.maxGroupsPerUser) {
          throw StateError('Group limit reached');
        }
        batch.set(groupRef, group.toMap());
        batch.set(firestore.collection('invites').doc(inviteCode), {
          'groupId': groupRef.id,
          'name': group.name,
          'icon': group.icon,
          'maxMembers': group.maxMembers,
          'memberCount': 1,
        });
        batch.set(
          groupRef.collection('members').doc(member.uid),
          member.toMap(),
        );
        batch.set(userDocRef, {
          'groupIds': FieldValue.arrayUnion([groupRef.id]),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      Navigator.of(context).pop();

      // Navigate to the newly created Group Detail Page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupDetailPage(groupId: groupRef.id),
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
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
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
                context.tr('create_group_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('create_group_subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 20),

              // Emoji Picker Grid
              Text(
                context.tr('group_icon_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _emojiOptions.map((emoji) {
                  final isSelected = _selectedEmoji == emoji;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandPrimary.withValues(
                                alpha: isDark ? 0.25 : 0.15,
                              )
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? brandPrimary : borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Group Name Input
              Text(
                context.tr('group_name_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('group_name_hint'),
                  hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: inputBg,
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
                    return context.tr('group_name_required');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description Input
              Text(
                context.tr('group_desc_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: context.tr('group_desc_hint'),
                  hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: inputBg,
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

              // Submit Button
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
                          context.tr('create_group_btn'),
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
