import '../../core/auth/auth_provider.dart';
import '../../core/data/firestore_provider.dart';
import '../../core/data/calendar_clock.dart';
import '../../core/data/completion_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../habits/providers/habits_provider.dart';
import '../pomodoro/providers/pomodoro_provider.dart';
import '../schedule/providers/schedule_provider.dart';
import '../tasks/providers/tasks_provider.dart';
import 'helpers/report_data_aggregator.dart';
import 'helpers/report_pdf_builder.dart';
import 'models/report_models.dart';

final reportHabitHistoryProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, days) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return Stream.value([]);
      final today = ref.watch(calendarClockProvider);
      return ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('habitLogs')
          .where(
            'date',
            isGreaterThanOrEqualTo: CompletionLedger.dateKey(
              calendarDay(today, 1 - days),
            ),
          )
          .where('date', isLessThanOrEqualTo: CompletionLedger.dateKey(today))
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    });

/// Screen providing interactive in-app PDF viewer, zoom, download, and print actions.
class ReportPreviewPage extends ConsumerWidget {
  final ReportRangeOption rangeOption;

  const ReportPreviewPage({super.key, required this.rangeOption});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final localizations = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final tasksAsync = ref.watch(tasksStreamProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final habitsAsync = ref.watch(habitsStreamProvider);
    final pomodoroAsync = ref.watch(pomodoroLogsStreamProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final historyAsync = ref.watch(
      reportHabitHistoryProvider(rangeOption.daysCount),
    );
    final sources = [
      tasksAsync,
      eventsAsync,
      habitsAsync,
      pomodoroAsync,
      categoriesAsync,
      historyAsync,
    ];
    if (sources.any((source) => source.hasError)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('pdf_reports_title'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('save_failed')),
              TextButton(
                onPressed: () {
                  ref.invalidate(tasksStreamProvider);
                  ref.invalidate(eventsStreamProvider);
                  ref.invalidate(habitsStreamProvider);
                  ref.invalidate(pomodoroLogsStreamProvider);
                  ref.invalidate(categoriesProvider);
                  ref.invalidate(
                    reportHabitHistoryProvider(rangeOption.daysCount),
                  );
                },
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (sources.any((source) => source.isLoading)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('pdf_reports_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final tasks = tasksAsync.requireValue;
    final events = eventsAsync.requireValue;
    final habits = habitsAsync.requireValue;
    final pomodoroLogs = pomodoroAsync.requireValue;
    final categories = categoriesAsync.requireValue;

    final reportData = ReportDataAggregator.aggregateReportData(
      rangeOption: rangeOption,
      tasks: tasks,
      events: events,
      habits: habits,
      pomodoroLogs: pomodoroLogs,
      categories: categories,
      habitLogs: historyAsync.requireValue,
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          localizations.tr('pdf_reports_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        centerTitle: false,
      ),
      body: PdfPreview(
        build: (format) => ReportPdfBuilder.buildReportPdf(
          data: reportData,
          localizations: localizations,
          isArabic: isArabic,
        ),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'focusly_report_${rangeOption.name}.pdf',
        previewPageMargin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF6366F1),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic
                        ? 'تعذّر إنشاء التقرير. أعد المحاولة أو احفظ التقرير على جهاز يدعم الطباعة.'
                        : 'The report could not be generated. Retry or use a device that supports printing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
