import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../time_blocker/models/time_block_type.dart';

/// Recurrence pattern options for calendar events
enum EventRecurrence {
  none(titleKey: 'recurrence_none'),
  daily(titleKey: 'recurrence_daily'),
  weekly(titleKey: 'recurrence_weekly'),
  monthly(titleKey: 'recurrence_monthly'),
  weekdays(titleKey: 'recurrence_weekdays'); // Monday through Friday

  final String titleKey;
  const EventRecurrence({required this.titleKey});

  static EventRecurrence fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'daily':
        return EventRecurrence.daily;
      case 'weekly':
        return EventRecurrence.weekly;
      case 'monthly':
        return EventRecurrence.monthly;
      case 'weekdays':
        return EventRecurrence.weekdays;
      case 'none':
      default:
        return EventRecurrence.none;
    }
  }
}

/// Calendar event data model stored in Firestore under users/{uid}/events/{eventId}.
///
/// If [blockType] is non-null, this event also acts as a Time Block in the Time Blocker view.
class EventModel {
  final String id;
  final String title;
  final String? note;
  final DateTime date;
  final TimeOfDay time;
  final String typeId;
  final EventRecurrence recurrence;
  final DateTime? recurrenceEnd;
  final DateTime createdAt;

  // Time Blocker Specific Fields
  final String? blockType; // 'deep' | 'shallow' | 'health' | 'leisure' | 'admin' | null
  final int? durationMinutes; // Duration in minutes (e.g. 30, 60, 90, 120...)

  const EventModel({
    required this.id,
    required this.title,
    this.note,
    required this.date,
    required this.time,
    required this.typeId,
    this.recurrence = EventRecurrence.none,
    this.recurrenceEnd,
    required this.createdAt,
    this.blockType,
    this.durationMinutes,
  });

  /// Returns true if this event repeats
  bool get isRecurring => recurrence != EventRecurrence.none;

  /// Returns true if this event is configured as a Time Block
  bool get isTimeBlock => blockType != null && blockType!.trim().isNotEmpty;

  /// Parsed [TimeBlockType] enum if valid
  TimeBlockType? get timeBlockType => TimeBlockType.fromString(blockType);

  /// Effective duration in minutes (defaults to 60 if unspecified)
  int get effectiveDurationMinutes => durationMinutes ?? 60;

  /// Computed end [TimeOfDay] from start time + effective duration
  TimeOfDay get endTime {
    final startMinutes = time.hour * 60 + time.minute;
    final endTotalMinutes = startMinutes + effectiveDurationMinutes;
    final endHour = (endTotalMinutes ~/ 60) % 24;
    final endMinute = endTotalMinutes % 60;
    return TimeOfDay(hour: endHour, minute: endMinute);
  }

  /// Combined start DateTime from date and time components
  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'typeId': typeId,
      'recurrence': recurrence.name,
      'recurrenceEnd': recurrenceEnd != null
          ? Timestamp.fromDate(DateTime(
              recurrenceEnd!.year,
              recurrenceEnd!.month,
              recurrenceEnd!.day,
              23,
              59,
              59,
            ))
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'blockType': blockType,
      'durationMinutes': durationMinutes,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedRecurrenceEnd;
    if (map['recurrenceEnd'] is Timestamp) {
      parsedRecurrenceEnd = (map['recurrenceEnd'] as Timestamp).toDate();
    } else if (map['recurrenceEnd'] is String) {
      parsedRecurrenceEnd = DateTime.tryParse(map['recurrenceEnd']);
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    TimeOfDay parsedTime = const TimeOfDay(hour: 9, minute: 0);
    if (map['time'] is String && (map['time'] as String).contains(':')) {
      final parts = (map['time'] as String).split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          parsedTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }

    int? parsedDuration;
    if (map['durationMinutes'] is int) {
      parsedDuration = map['durationMinutes'] as int;
    } else if (map['durationMinutes'] is num) {
      parsedDuration = (map['durationMinutes'] as num).toInt();
    }

    return EventModel(
      id: docId,
      title: map['title'] ?? '',
      note: map['note'],
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      time: parsedTime,
      typeId: map['typeId'] ?? 'work_meeting',
      recurrence: EventRecurrence.fromString(map['recurrence']),
      recurrenceEnd: parsedRecurrenceEnd != null
          ? DateTime(
              parsedRecurrenceEnd.year,
              parsedRecurrenceEnd.month,
              parsedRecurrenceEnd.day,
            )
          : null,
      createdAt: parsedCreatedAt,
      blockType: map['blockType'] as String?,
      durationMinutes: parsedDuration,
    );
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? date,
    TimeOfDay? time,
    String? typeId,
    EventRecurrence? recurrence,
    DateTime? recurrenceEnd,
    DateTime? createdAt,
    bool clearRecurrenceEnd = false,
    String? blockType,
    bool clearBlockType = false,
    int? durationMinutes,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      date: date != null ? DateTime(date.year, date.month, date.day) : this.date,
      time: time ?? this.time,
      typeId: typeId ?? this.typeId,
      recurrence: recurrence ?? this.recurrence,
      recurrenceEnd: clearRecurrenceEnd ? null : (recurrenceEnd ?? this.recurrenceEnd),
      createdAt: createdAt ?? this.createdAt,
      blockType: clearBlockType ? null : (blockType ?? this.blockType),
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
