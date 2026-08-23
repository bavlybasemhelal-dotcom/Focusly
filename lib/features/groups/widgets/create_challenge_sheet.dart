import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../services/challenge_service.dart';

/// Modal bottom sheet for creating a new Group Challenge.
class CreateChallengeSheet extends StatefulWidget {
  final String groupId;

  const CreateChallengeSheet({super.key, required this.groupId});

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _goalController = TextEditingController(text: '10');

  String _selectedType = 'tasks'; // 'tasks' | 'habits' | 'xp'
  int _selectedDuration = 7; // 3, 7, 14, 30 days
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final goal = int.tryParse(_goalController.text.trim());
    if (goal == null || goal <= 0) return;

    setState(() {
      _isSubmitting = true;
    });

    final res = await ChallengeService().createChallenge(
      groupId: widget.groupId,
      title: _titleController.text.trim(),
      type: _selectedType,
      goal: goal,
      durationDays: _selectedDuration,
    );

    if (!mounted) return;

    if (res != null) {
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
              const Text('🚀', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('challenge_created_success'),
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
    } else {
      setState(() {
        _isSubmitting = false;
      });
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
                context.tr('create_challenge_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('create_challenge_subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 20),

              // Challenge Title Input
              Text(
                context.tr('challenge_title_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('challenge_title_hint'),
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
                    return context.tr('challenge_title_required');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Type Selector Chips
              Text(
                context.tr('challenge_type_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeChip('tasks', '🎯', context.tr('challenge_type_tasks'), brandPrimary, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('habits', '🔥', context.tr('challenge_type_habits'), brandPrimary, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('xp', '⚡', context.tr('challenge_type_xp'), brandPrimary, isDark),
                ],
              ),

              const SizedBox(height: 18),

              // Target Goal Input
              Text(
                context.tr('challenge_goal_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '10',
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
                  final numVal = int.tryParse(val ?? '');
                  if (numVal == null || numVal <= 0) {
                    return context.tr('invalid_goal');
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Duration Chips (3, 7, 14, 30 days)
              Text(
                context.tr('challenge_duration_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [3, 7, 14, 30].map((days) {
                  final isSelected = _selectedDuration == days;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDuration = days;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? brandPrimary
                                : (isDark
                                    ? const Color(0xFF0F1B4C)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? brandPrimary
                                  : borderColor,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$days ${context.tr('days_short')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 26),

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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          context.tr('launch_challenge_btn'),
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

  Widget _buildTypeChip(
    String type,
    String emoji,
    String label,
    Color brandPrimary,
    bool isDark,
  ) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type == 'xp' && _goalController.text == '10') {
              _goalController.text = '200';
            } else if (type != 'xp' && _goalController.text == '200') {
              _goalController.text = '10';
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? brandPrimary.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? brandPrimary : (isDark ? Colors.white12 : const Color(0xFFE2E8F5)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? brandPrimary
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
