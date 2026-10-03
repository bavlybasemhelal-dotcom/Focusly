import '../../tasks/models/task_model.dart';
import '../../workout_tracker/models/workout_model.dart';
import '../../reading_tracker/models/book_model.dart';
import '../../energy_mood/models/checkin_model.dart';

/// Aggregated year-over-year statistics computed live across existing feature modules
class YearStatsData {
  final int tasks;
  final int workouts;
  final int books;
  final double? avgEnergy;

  const YearStatsData({
    this.tasks = 0,
    this.workouts = 0,
    this.books = 0,
    this.avgEnergy,
  });

  /// Formatted energy string (e.g. "4.2" or "−" if no check-ins logged)
  String get formattedEnergy {
    if (avgEnergy == null) return '−';
    return avgEnergy!.toStringAsFixed(1);
  }
}

/// Pure computation function calculating live yearly productivity statistics
/// across Tasks, Workout Tracker, Reading Tracker, and Energy & Mood Check-ins.
YearStatsData calculateYearStats(
  int year, {
  List<TaskModel> tasks = const [],
  List<WorkoutModel> workouts = const [],
  List<BookModel> books = const [],
  List<CheckinModel> checkins = const [],
}) {
  // 1. Tasks: Completed tasks whose date or completion falls in [year]
  final tasksCount = tasks.where((task) {
    if (!task.done) return false;
    final taskYear = task.doneAt?.year ?? task.date.year;
    return taskYear == year;
  }).length;

  // 2. Workouts: Logged workouts whose workout date falls in [year]
  final workoutsCount = workouts.where((workout) {
    return workout.date.year == year;
  }).length;

  // 3. Books: Completed books ('done') finished in [year]
  final booksCount = books.where((book) {
    if (book.status != 'done') return false;
    final finishYear = book.finishDate?.year ?? book.updatedAt.year;
    return finishYear == year;
  }).length;

  // 4. Energy: Average energy rating (1-5) across check-ins logged in [year]
  final yearCheckins = checkins.where((checkin) {
    int? checkinYear;
    try {
      final parts = checkin.date.split('-');
      if (parts.isNotEmpty) {
        checkinYear = int.tryParse(parts[0]);
      }
    } catch (_) {}
    checkinYear ??= checkin.createdAt.year;
    return checkinYear == year;
  }).toList();

  double? avgEnergy;
  if (yearCheckins.isNotEmpty) {
    final totalEnergy = yearCheckins.fold<int>(0, (sum, c) => sum + c.energy);
    avgEnergy = (totalEnergy / yearCheckins.length * 10).round() / 10.0;
  }

  return YearStatsData(
    tasks: tasksCount,
    workouts: workoutsCount,
    books: booksCount,
    avgEnergy: avgEnergy,
  );
}
