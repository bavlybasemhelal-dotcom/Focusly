import 'package:flutter/material.dart';
import '../../schedule/models/event_model.dart';

/// Pure computation helper functions for 24-hour daily time blocking logic.
class TimeBlockerHelper {
  /// Returns whether a given [event] overlaps with the 1-hour slot for [hour] (0..23).
  ///
  /// Mathematical Interval Overlap Rule:
  /// Slot interval: `[hour * 60, (hour + 1) * 60)`
  /// Event interval: `[startMinutes, startMinutes + effectiveDurationMinutes)`
  static bool doesBlockSpanHour(EventModel event, int hour) {
    if (hour < 0 || hour > 23) return false;

    final startMinutes = event.time.hour * 60 + event.time.minute;
    final endMinutes = startMinutes + event.effectiveDurationMinutes;

    final slotStartMinutes = hour * 60;
    final slotEndMinutes = (hour + 1) * 60;

    return startMinutes < slotEndMinutes && endMinutes > slotStartMinutes;
  }

  /// Returns the first [EventModel] in [blocks] that spans the specified [hour] (0..23),
  /// or null if the hour slot is empty.
  static EventModel? getBlockForHour(List<EventModel> blocks, int hour) {
    for (final block in blocks) {
      if (doesBlockSpanHour(block, hour)) {
        return block;
      }
    }
    return null;
  }

  /// Returns true if [hour] is the exact starting hour of the [event].
  static bool isBlockStartHour(EventModel event, int hour) {
    return event.time.hour == hour;
  }

  /// Formats a time range string, e.g. "09:00 – 10:30"
  static String formatTimeRange(TimeOfDay start, TimeOfDay end) {
    final startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startStr – $endStr';
  }

  /// Formats a duration in minutes to a clean human-readable string (e.g. "1h 30m" or "45m")
  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0 && remainingMinutes > 0) {
      return '${hours}h ${remainingMinutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${remainingMinutes}m';
    }
  }

  /// Computes total planned minutes for a list of daily blocks
  static int computeTotalPlannedMinutes(List<EventModel> blocks) {
    int total = 0;
    for (final block in blocks) {
      total += block.effectiveDurationMinutes;
    }
    return total;
  }
}
