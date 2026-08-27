import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/event_model.dart';
import '../models/event_type_model.dart';
import '../providers/schedule_provider.dart';
import '../../time_blocker/models/time_block_type.dart';
import '../../time_blocker/helpers/time_blocker_helper.dart';

/// Modal bottom sheet for creating a new calendar event or editing an existing one.
/// Also used for creating/editing Time Blocks when blockType is specified.
class AddEditEventSheet extends ConsumerStatefulWidget {
  final EventModel? eventToEdit;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialTitle;
  final String? initialBlockType;
  final int? initialDurationMinutes;

  const AddEditEventSheet({
    super.key,
    this.eventToEdit,
    this.initialDate,
    this.initialTime,
    this.initialTitle,
    this.initialBlockType,
    this.initialDurationMinutes,
  });

  @override
  ConsumerState<AddEditEventSheet> createState() => _AddEditEventSheetState();
}

class _AddEditEventSheetState extends ConsumerState<AddEditEventSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedTypeId;
  late EventRecurrence _selectedRecurrence;
  DateTime? _selectedRecurrenceEnd;
  String? _selectedBlockType;
  late int _selectedDurationMinutes;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;

    _titleController =
        TextEditingController(text: event?.title ?? (widget.initialTitle ?? ''));
    _noteController = TextEditingController(text: event?.note ?? '');
    _selectedDate = event?.date ?? (widget.initialDate ?? DateTime.now());
    _selectedTime = event?.time ?? (widget.initialTime ?? const TimeOfDay(hour: 10, minute: 0));
    _selectedTypeId = event?.typeId ?? 'work_meeting';
    _selectedRecurrence = event?.recurrence ?? EventRecurrence.none;
    _selectedRecurrenceEnd = event?.recurrenceEnd;
    _selectedBlockType = event?.blockType ?? (widget.initialBlockType ?? 'general');
    _selectedDurationMinutes =
        event?.effectiveDurationMinutes ?? (widget.initialDurationMinutes ?? 60);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // If editing a recurring event, ask user preference
    if (widget.eventToEdit != null && widget.eventToEdit!.isRecurring) {
      final bool? editAll = await _showRecurringEditOptionsDialog();
      if (editAll == null || !mounted) return;
    }

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : null;

    final controller = ref.read(scheduleControllerProvider);

    if (widget.eventToEdit != null) {
      final updated = widget.eventToEdit!.copyWith(
        title: title,
        note: note,
        date: _selectedDate,
        time: _selectedTime,
        typeId: _selectedTypeId,
        recurrence: _selectedRecurrence,
        recurrenceEnd: _selectedRecurrence != EventRecurrence.none
            ? _selectedRecurrenceEnd
            : null,
        clearRecurrenceEnd: _selectedRecurrence == EventRecurrence.none,
        blockType: _selectedBlockType ?? 'general',
        durationMinutes: _selectedDurationMinutes,
      );
      if (!mounted) return;
      await controller.updateEvent(updated, context);
    } else {
      final newEvent = EventModel(
        id: '',
        title: title,
        note: note,
        date: _selectedDate,
        time: _selectedTime,
        typeId: _selectedTypeId,
        recurrence: _selectedRecurrence,
        recurrenceEnd: _selectedRecurrence != EventRecurrence.none
            ? _selectedRecurrenceEnd
            : null,
        createdAt: DateTime.now(),
        blockType: _selectedBlockType ?? 'general',
        durationMinutes: _selectedDurationMinutes,
      );
      if (!mounted) return;
      await controller.addEvent(newEvent, context);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Dialog when modifying a repeating event series
  ///
  /// TODO: Single occurrence exception overrides ("Edit this occurrence only") can be
  /// implemented in future releases by storing an exclusion list and creating a one-off detached event.
  Future<bool?> _showRecurringEditOptionsDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('edit_recurring_title'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          content: Text(context.tr('edit_recurring_prompt')),
          actions: [
            TextButton(
              onPressed: () {
                // TODO: Wire single occurrence exception override
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(context.tr('edit_this_occurrence_only')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(context.tr('edit_all_occurrences')),
            ),
          ],
        );
      },
    );
  }

  /// Opens dialog to create a new custom event type
  Future<void> _showAddEventTypeDialog() async {
    final nameController = TextEditingController();
    int selectedColor = 0xFF2563EB;
    final List<int> palette = [
      0xFF2563EB, // Royal Blue
      0xFF8B5CF6, // Purple
      0xFF10B981, // Emerald
      0xFFEC4899, // Pink
      0xFF0EA5E9, // Sky Blue
      0xFFF59E0B, // Amber
      0xFFEF4444, // Red
      0xFF64748B, // Slate
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.tr('add_event_type_title'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('event_type_name_hint'),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('select_color'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: palette.map((colorVal) {
                      final isSelected = selectedColor == colorVal;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = colorVal;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(colorVal),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(colorVal).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      await ref
                          .read(scheduleControllerProvider)
                          .addCustomEventType(name, selectedColor);
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlueVibrant,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(context.tr('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = AppColors.border(context);

    final eventTypesAsync = ref.watch(eventTypesStreamProvider);
    final eventTypes = eventTypesAsync.value ?? EventType.defaultEventTypes;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.eventToEdit != null
                          ? context.tr('edit_event')
                          : context.tr('new_event'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. Title Input (Required)
                TextFormField(
                  controller: _titleController,
                  autofocus: widget.eventToEdit == null,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('event_title_required');
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('event_title_hint'),
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brandPrimary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Date & Time Selectors Row (Both Required)
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      child: _buildPickerButton(
                        label: context.tr('date'),
                        value: DateFormat.yMMMd().format(_selectedDate),
                        icon: Icons.calendar_today_rounded,
                        color: brandPrimary,
                        isDark: isDark,
                        borderColor: borderColor,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Time Picker (Full arbitrary hour & minute picker: e.g. 4:16 PM / 16:16)
                    Expanded(
                      child: _buildPickerButton(
                        label: context.tr('time'),
                        value: _selectedTime.format(context),
                        icon: Icons.access_time_rounded,
                        color: const Color(0xFF0EA5E9),
                        isDark: isDark,
                        borderColor: borderColor,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedTime = picked;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Event Type Selector Chips
                _buildFieldLabel(context.tr('event_type'), primaryTextColor),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...eventTypes.map((type) {
                        final isSelected = _selectedTypeId == type.id;
                        final typeName = type.isDefault
                            ? context.tr(type.nameKey)
                            : type.nameKey;

                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8.0),
                          child: ChoiceChip(
                            avatar: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white : type.color,
                              ),
                            ),
                            label: Text(typeName),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                            ),
                            selected: isSelected,
                            selectedColor: type.color,
                            backgroundColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? type.color : borderColor,
                                width: 1.2,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTypeId = type.id;
                                });
                              }
                            },
                          ),
                        );
                      }),
                      // Add Custom Type Button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandPrimary.withValues(alpha: 0.15),
                          ),
                          child: Icon(Icons.add, size: 18, color: brandPrimary),
                        ),
                        onPressed: _showAddEventTypeDialog,
                        tooltip: context.tr('add_event_type_title'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3.5. Time Block Type (Optional / Time Blocker Mode)
                _buildFieldLabel(context.tr('block_type_label'), primaryTextColor),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 6 Time Block Types (General / Deep / Shallow / Health / Leisure / Admin)
                      ...TimeBlockType.values.map((block) {
                        final isSelected = _selectedBlockType == block.id;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8.0),
                          child: ChoiceChip(
                            avatar: Text(block.emoji, style: const TextStyle(fontSize: 13)),
                            label: Text(context.tr(block.labelKey)),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                            ),
                            selected: isSelected,
                            selectedColor: block.color,
                            backgroundColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? block.color : borderColor,
                                width: 1.2,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedBlockType = block.id);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3.6. Duration Selector (with live range computation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFieldLabel(context.tr('duration_label'), primaryTextColor),
                    // Live Computed Time Range Display
                    Builder(builder: (_) {
                      final startM = _selectedTime.hour * 60 + _selectedTime.minute;
                      final endTot = startM + _selectedDurationMinutes;
                      final computedEnd = TimeOfDay(hour: (endTot ~/ 60) % 24, minute: endTot % 60);
                      final rangeStr = TimeBlockerHelper.formatTimeRange(_selectedTime, computedEnd);
                      final durStr = TimeBlockerHelper.formatDuration(_selectedDurationMinutes);
                      return Text(
                        '$rangeStr ($durStr)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brandPrimary,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [30, 45, 60, 90, 120, 180].map((dur) {
                      final isSelected = _selectedDurationMinutes == dur;
                      final durLabel = TimeBlockerHelper.formatDuration(dur);
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8.0),
                        child: ChoiceChip(
                          label: Text(durLabel),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                          ),
                          selected: isSelected,
                          selectedColor: brandPrimary,
                          backgroundColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? brandPrimary : borderColor,
                              width: 1.2,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedDurationMinutes = dur);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Recurrence Selector
                _buildFieldLabel(context.tr('recurrence'), primaryTextColor),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: EventRecurrence.values.map((rec) {
                      final isSelected = _selectedRecurrence == rec;
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8.0),
                        child: ChoiceChip(
                          label: Text(context.tr(rec.titleKey)),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                          ),
                          selected: isSelected,
                          selectedColor: brandPrimary,
                          backgroundColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? brandPrimary : borderColor,
                              width: 1.2,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedRecurrence = rec;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Recurrence End Date Picker (Only if recurring)
                if (_selectedRecurrence != EventRecurrence.none) ...[
                  _buildPickerButton(
                    label: context.tr('recurrence_end'),
                    value: _selectedRecurrenceEnd != null
                        ? DateFormat.yMMMd().format(_selectedRecurrenceEnd!)
                        : context.tr('never_ends'),
                    icon: Icons.event_repeat_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    borderColor: borderColor,
                    hasClear: _selectedRecurrenceEnd != null,
                    onClear: () {
                      setState(() {
                        _selectedRecurrenceEnd = null;
                      });
                    },
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedRecurrenceEnd ??
                            _selectedDate.add(const Duration(days: 30)),
                        firstDate: _selectedDate,
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedRecurrenceEnd = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 6. Note Field (Optional)
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: context.tr('event_note_hint'),
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brandPrimary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 7. Save / Update Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.cyanElectric.withValues(alpha: 0.35)
                            : const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                      foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: isDark ? const Color(0xFF060B24) : Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            widget.eventToEdit != null
                                ? context.tr('update_event')
                                : context.tr('create_event'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
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

  Widget _buildPickerButton({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTap,
    bool hasClear = false,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasClear)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.clear_rounded, size: 16, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
