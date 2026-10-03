import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A shared clock keeps day/week projections fresh after midnight.
final calendarClockStreamProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  yield DateTime.now();
  yield* Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  ).distinct((previous, next) => calendarDay(previous) == calendarDay(next));
});
final calendarClockProvider = Provider.autoDispose<DateTime>((ref) {
  return calendarDay(
    ref.watch(calendarClockStreamProvider).value ?? DateTime.now(),
  );
});

DateTime calendarDay(DateTime value, [int offset = 0]) =>
    DateTime(value.year, value.month, value.day + offset);
int calendarDaysBetween(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
