import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/schedule/helpers/recurrence_helper.dart';
import 'package:focusly/features/schedule/models/event_model.dart';

void main() {
  group('Schedule Recurrence Engine Tests', () {
    final baseDate = DateTime(2026, 8, 1); // Saturday

    test('Non-recurring event occurs only on exact event date', () {
      final event = EventModel(
        id: '1',
        title: 'Single Team Sync',
        date: baseDate,
        time: const TimeOfDay(hour: 14, minute: 0),
        typeId: 'work_meeting',
        recurrence: EventRecurrence.none,
        createdAt: baseDate,
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, baseDate), isTrue);
      expect(
        RecurrenceHelper.doesEventOccurOn(
          event,
          baseDate.add(const Duration(days: 1)),
        ),
        isFalse,
      );
      expect(
        RecurrenceHelper.doesEventOccurOn(
          event,
          baseDate.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('Daily event occurs every day on and after event date', () {
      final event = EventModel(
        id: '2',
        title: 'Daily Meditation',
        date: baseDate,
        time: const TimeOfDay(hour: 7, minute: 30),
        typeId: 'personal',
        recurrence: EventRecurrence.daily,
        createdAt: baseDate,
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, baseDate), isTrue);
      expect(
        RecurrenceHelper.doesEventOccurOn(
          event,
          baseDate.add(const Duration(days: 5)),
        ),
        isTrue,
      );
      expect(
        RecurrenceHelper.doesEventOccurOn(
          event,
          baseDate.add(const Duration(days: 20)),
        ),
        isTrue,
      );
      expect(
        RecurrenceHelper.doesEventOccurOn(
          event,
          baseDate.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('Weekly event occurs only on the matching weekday', () {
      final event = EventModel(
        id: '3',
        title: 'Weekly Sprint Planning',
        date: DateTime(2026, 8, 3), // Monday
        time: const TimeOfDay(hour: 10, minute: 0),
        typeId: 'work_meeting',
        recurrence: EventRecurrence.weekly,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 3)), isTrue); // Mon
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 10)), isTrue); // Next Mon
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 17)), isTrue); // Next Mon
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 4)), isFalse); // Tue
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 9)), isFalse); // Sun
    });

    test('Monthly event occurs on the same day-of-month', () {
      final event = EventModel(
        id: '4',
        title: 'Monthly Performance Review',
        date: DateTime(2026, 8, 15),
        time: const TimeOfDay(hour: 11, minute: 0),
        typeId: 'work_meeting',
        recurrence: EventRecurrence.monthly,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 15)), isTrue);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 9, 15)), isTrue);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 10, 15)), isTrue);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 16)), isFalse);
    });

    test('Weekdays-only event occurs on Mon-Fri and skips Sat-Sun', () {
      final event = EventModel(
        id: '5',
        title: 'Weekday Standup',
        date: DateTime(2026, 8, 3), // Monday
        time: const TimeOfDay(hour: 9, minute: 0),
        typeId: 'work_meeting',
        recurrence: EventRecurrence.weekdays,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 3)), isTrue); // Mon
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 4)), isTrue); // Tue
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 5)), isTrue); // Wed
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 6)), isTrue); // Thu
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 7)), isTrue); // Fri
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 8)), isFalse); // Sat
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 9)), isFalse); // Sun
    });

    test('Recurrence end date strictly halts occurrences', () {
      final event = EventModel(
        id: '6',
        title: 'Summer Training Camp',
        date: DateTime(2026, 8, 1),
        time: const TimeOfDay(hour: 16, minute: 0),
        typeId: 'training_sport',
        recurrence: EventRecurrence.daily,
        recurrenceEnd: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 8, 1),
      );

      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 5)), isTrue);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 10)), isTrue);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 11)), isFalse);
      expect(RecurrenceHelper.doesEventOccurOn(event, DateTime(2026, 8, 20)), isFalse);
    });

    test('expandEventsForDateRange expands occurrences chronologically', () {
      final events = [
        EventModel(
          id: 'e1',
          title: 'Daily Evening Walk',
          date: DateTime(2026, 8, 1),
          time: const TimeOfDay(hour: 19, minute: 0),
          typeId: 'training_sport',
          recurrence: EventRecurrence.daily,
          createdAt: DateTime(2026, 8, 1),
        ),
        EventModel(
          id: 'e2',
          title: 'Daily Morning Coffee',
          date: DateTime(2026, 8, 1),
          time: const TimeOfDay(hour: 8, minute: 0),
          typeId: 'personal',
          recurrence: EventRecurrence.daily,
          createdAt: DateTime(2026, 8, 1),
        ),
      ];

      final occurrences = RecurrenceHelper.getOccurrencesForDay(
        events,
        DateTime(2026, 8, 2),
      );

      expect(occurrences.length, 2);
      expect(occurrences.first.title, 'Daily Morning Coffee');
      expect(occurrences.last.title, 'Daily Evening Walk');
    });
  });
}
