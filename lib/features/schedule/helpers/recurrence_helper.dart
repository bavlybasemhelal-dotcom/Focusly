import 'package:flutter/material.dart';
import '../models/event_model.dart';

/// Single concrete occurrence of an event on a specific date.
class EventOccurrence {
  final EventModel event;
  final DateTime date; // Normalized occurrence date (year, month, day)

  const EventOccurrence({
    required this.event,
    required this.date,
  });

  String get id => event.id;
  String get title => event.title;
  String? get note => event.note;
  TimeOfDay get time => event.time;
  String get typeId => event.typeId;
  EventRecurrence get recurrence => event.recurrence;
  bool get isRecurring => event.isRecurring;

  /// Full DateTime representing the occurrence start instant
  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  /// Sort priority key in minutes from midnight (0 .. 1439)
  int get minuteOfDay => time.hour * 60 + time.minute;
}

/// Pure helper functions for recurrence evaluation and expansion without side effects.
class RecurrenceHelper {
  /// Normalizes a DateTime to midnight (00:00:00.000)
  static DateTime normalizeDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Pure function checking if an event occurs on a specific target date
  static bool doesEventOccurOn(EventModel event, DateTime targetDate) {
    final target = normalizeDate(targetDate);
    final eventStart = normalizeDate(event.date);

    // Occurrences cannot precede the initial event start date
    if (target.isBefore(eventStart)) {
      return false;
    }

    // Occurrences cannot proceed past the recurrence end date (if specified)
    if (event.recurrenceEnd != null) {
      final end = normalizeDate(event.recurrenceEnd!);
      if (target.isAfter(end)) {
        return false;
      }
    }

    switch (event.recurrence) {
      case EventRecurrence.none:
        return target.isAtSameMomentAs(eventStart);

      case EventRecurrence.daily:
        return true;

      case EventRecurrence.weekly:
        return target.weekday == eventStart.weekday;

      case EventRecurrence.monthly:
        // Occurs on the same day-of-month
        if (target.day == eventStart.day) {
          return true;
        }
        // Handle edge cases for months with fewer days (e.g. 31st on Feb)
        final lastDayOfTargetMonth = DateTime(target.year, target.month + 1, 0).day;
        if (eventStart.day > lastDayOfTargetMonth && target.day == lastDayOfTargetMonth) {
          return true;
        }
        return false;

      case EventRecurrence.weekdays:
        // Monday (1) through Friday (5)
        return target.weekday >= DateTime.monday &&
            target.weekday <= DateTime.friday;
    }
  }

  /// Returns all event occurrences on a specific target day, ordered by time.
  static List<EventOccurrence> getOccurrencesForDay(
    List<EventModel> events,
    DateTime day,
  ) {
    final normalizedDay = normalizeDate(day);
    final List<EventOccurrence> occurrences = [];

    for (final event in events) {
      if (doesEventOccurOn(event, normalizedDay)) {
        occurrences.add(
          EventOccurrence(
            event: event,
            date: normalizedDay,
          ),
        );
      }
    }

    // Sort chronologically by time of day
    occurrences.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    return occurrences;
  }

  /// Expands all occurrences across a specified date range (inclusive).
  static List<EventOccurrence> expandEventsForDateRange(
    List<EventModel> events,
    DateTime startRange,
    DateTime endRange,
  ) {
    final start = normalizeDate(startRange);
    final end = normalizeDate(endRange);
    final List<EventOccurrence> results = [];

    DateTime current = start;
    while (!current.isAfter(end)) {
      results.addAll(getOccurrencesForDay(events, current));
      current = current.add(const Duration(days: 1));
    }

    results.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return results;
  }

  /// Returns a map of normalized Date -> `List<EventOccurrence>` for quick calendar day lookups
  static Map<DateTime, List<EventOccurrence>> groupOccurrencesByDay(
    List<EventModel> events,
    DateTime startRange,
    DateTime endRange,
  ) {
    final start = normalizeDate(startRange);
    final end = normalizeDate(endRange);
    final Map<DateTime, List<EventOccurrence>> map = {};

    DateTime current = start;
    while (!current.isAfter(end)) {
      final dayOccurrences = getOccurrencesForDay(events, current);
      if (dayOccurrences.isNotEmpty) {
        map[current] = dayOccurrences;
      }
      current = current.add(const Duration(days: 1));
    }

    return map;
  }
}
