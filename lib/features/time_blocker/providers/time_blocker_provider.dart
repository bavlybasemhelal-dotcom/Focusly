import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../schedule/helpers/recurrence_helper.dart';
import '../../schedule/models/event_model.dart';
import '../../schedule/providers/schedule_provider.dart';

/// State notifier managing the currently selected date for the 24-hour Time Blocker view.
class TimeBlockerSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return RecurrenceHelper.normalizeDate(now);
  }

  /// Selects a specific date on the timeline
  void selectDate(DateTime date) {
    state = RecurrenceHelper.normalizeDate(date);
  }

  /// Advances to the next calendar day
  void nextDay() {
    state = state.add(const Duration(days: 1));
  }

  /// Steps back to the previous calendar day
  void previousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  /// Jumps back to today
  void jumpToToday() {
    state = RecurrenceHelper.normalizeDate(DateTime.now());
  }
}

/// Global provider for the selected timeline date
final timeBlockerSelectedDateProvider =
    NotifierProvider<TimeBlockerSelectedDateNotifier, DateTime>(
  TimeBlockerSelectedDateNotifier.new,
);

/// Derived provider filtering all user events for the selected date down to Time Blocks.
///
/// DATA REUSE: Reuses the existing [eventsStreamProvider] and [RecurrenceHelper]
/// from the Schedule module, ensuring complete synchronization without a separate database collection.
/// Every event on this date (including default General events created in Schedule) appears here.
final timeBlocksForSelectedDateProvider = Provider<List<EventModel>>((ref) {
  final eventsAsync = ref.watch(eventsStreamProvider);
  final selectedDate = ref.watch(timeBlockerSelectedDateProvider);
  final allEvents = eventsAsync.value ?? [];

  // Filter to all events that occur on the selected date
  final blocks = allEvents.where((event) {
    return RecurrenceHelper.doesEventOccurOn(event, selectedDate);
  }).toList();

  // Sort by start time of day in minutes
  blocks.sort((a, b) {
    final aMins = a.time.hour * 60 + a.time.minute;
    final bMins = b.time.hour * 60 + b.time.minute;
    return aMins.compareTo(bMins);
  });

  return blocks;
});
