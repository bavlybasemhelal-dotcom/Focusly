import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/energy_mood_provider.dart';
import '../services/energy_mood_service.dart';
import 'water_sleep_widgets.dart';

/// Modal bottom sheet for performing a daily Energy & Mood check-in.
class CheckinSheet extends ConsumerStatefulWidget {
  final String? initialDateStr;

  const CheckinSheet({super.key, this.initialDateStr});

  static Future<void> show(BuildContext context, {String? dateStr}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckinSheet(initialDateStr: dateStr),
    );
  }

  @override
  ConsumerState<CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends ConsumerState<CheckinSheet> {
  late DateTime _selectedDate;
  int? _selectedEnergy = 3;
  String? _selectedMood = '🙂';
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _errorMessage;

  static const List<Map<String, dynamic>> _energyOptions = [
    {
      'level': 1,
      'labelKey': 'energy_level_1',
      'icon': Icons.battery_1_bar_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'level': 2,
      'labelKey': 'energy_level_2',
      'icon': Icons.battery_2_bar_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'level': 3,
      'labelKey': 'energy_level_3',
      'icon': Icons.battery_4_bar_rounded,
      'color': Color(0xFFFBBF24),
    },
    {
      'level': 4,
      'labelKey': 'energy_level_4',
      'icon': Icons.battery_5_bar_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'level': 5,
      'labelKey': 'energy_level_5',
      'icon': Icons.battery_full_rounded,
      'color': Color(0xFF06B6D4),
    },
  ];

  static const List<String> _moodOptions = ['😞', '😐', '🙂', '😊', '🤩'];

  @override
  void initState() {
    super.initState();
    if (widget.initialDateStr != null) {
      _selectedDate =
          DateTime.tryParse(widget.initialDateStr!) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }
    _noteController = TextEditingController();
    _loadExistingCheckin();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _dateString => EnergyMoodService.formatDate(_selectedDate);

  Future<void> _loadExistingCheckin() async {
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      final existing = await ref
          .read(energyMoodServiceProvider)
          .getCheckin(uid, _dateString);
      if (existing != null && mounted) {
        setState(() {
          _selectedEnergy = existing.energy;
          _selectedMood = existing.mood;
          _noteController.text = existing.note ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _onDateChanged(DateTime newDate) async {
    setState(() {
      _selectedDate = newDate;
      _errorMessage = null;
    });
    await _loadExistingCheckin();
  }

  Future<void> _handleSave() async {
    if (_selectedEnergy == null) {
      setState(() {
        _errorMessage = context.tr('energy_required_warning');
      });
      return;
    }
    if (_selectedMood == null) {
      setState(() {
        _errorMessage = context.tr('mood_required_warning');
      });
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final noteText = _noteController.text.trim();

    final success = await ref
        .read(energyMoodServiceProvider)
        .saveCheckin(
          uid: uid,
          date: _dateString,
          energy: _selectedEnergy!,
          mood: _selectedMood!,
          note: noteText.isNotEmpty ? noteText : null,
          context: context,
          ref: ref,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('checkin_saved_toast'))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = context.tr('checkin_save_error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final checkinAsync = ref.watch(checkinForDateStreamProvider(_dateString));
    final liveCheckin = checkinAsync.value;

    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateDisplay = isToday
        ? context.tr('today')
        : DateFormat.yMMMMd().format(_selectedDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Date Selector Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('daily_checkin_title'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('daily_checkin_subtitle'),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Date Picker Button (Max today)
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate:
                            DateTime.now(), // Can't check in for future dates
                      );
                      if (picked != null) {
                        _onDateChanged(picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F1B4C)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: const Color(0xFF2E6FF2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 1. Energy Level Selector (1 to 5)
              Text(
                context.tr('energy_level_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _energyOptions.map((opt) {
                  final level = opt['level'] as int;
                  final labelKey = opt['labelKey'] as String;
                  final icon = opt['icon'] as IconData;
                  final color = opt['color'] as Color;
                  final isSelected = _selectedEnergy == level;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedEnergy = level;
                            _errorMessage = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                    0xFF2E6FF2,
                                  ).withValues(alpha: 0.15)
                                : (isDark
                                      ? const Color(0xFF08123A)
                                      : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2E6FF2)
                                  : (isDark
                                        ? Colors.white12
                                        : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2E6FF2,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                icon,
                                color: isSelected
                                    ? const Color(0xFF2E6FF2)
                                    : color,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$level',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? const Color(0xFF2E6FF2)
                                      : primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr(labelKey),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF2E6FF2)
                                      : secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 2. Mood Selector (5 emojis)
              Text(
                context.tr('mood_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _moodOptions.map((emoji) {
                  final isSelected = _selectedMood == emoji;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedMood = emoji;
                        _errorMessage = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2E6FF2).withValues(alpha: 0.15)
                            : (isDark
                                  ? const Color(0xFF08123A)
                                  : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2E6FF2)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2E6FF2,
                                  ).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Short Note Field (Optional)
              Text(
                context.tr('checkin_note_label'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('checkin_note_hint'),
                  hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E6FF2),
                      width: 1.8,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Integrated Water & Sleep Trackers
              WaterTrackerWidget(
                dateStr: _dateString,
                checkin: liveCheckin,
                isCompact: true,
              ),
              const SizedBox(height: 12),
              SleepTrackerWidget(dateStr: _dateString, checkin: liveCheckin),
              const SizedBox(height: 20),

              // Error Message Warning (if any)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.errorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Save Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: isDark
                        ? const Color(0xFF060B24)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('save_checkin_btn'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
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
