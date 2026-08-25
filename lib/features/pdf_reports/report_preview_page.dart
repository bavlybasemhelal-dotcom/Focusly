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

/// Screen providing interactive in-app PDF viewer, zoom, download, and print actions.
class ReportPreviewPage extends ConsumerWidget {
  final ReportRangeOption rangeOption;

  const ReportPreviewPage({
    super.key,
    required this.rangeOption,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final localizations = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final events = ref.watch(eventsStreamProvider).value ?? [];
    final habits = ref.watch(habitsStreamProvider).value ?? [];
    final pomodoroLogs = ref.watch(pomodoroLogsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];

    final reportData = ReportDataAggregator.aggregateReportData(
      rangeOption: rangeOption,
      tasks: tasks,
      events: events,
      habits: habits,
      pomodoroLogs: pomodoroLogs,
      categories: categories,
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
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        loadingWidget: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6366F1),
          ),
        ),
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    isArabic
                        ? 'يرجى إعادة تشغيل التطبيق بالكامل (Full Restart) لتفعيل حزمة الطباعة والتصدير على نظام التشغيل.'
                        : 'Please fully restart the app (Stop & Run) to register the native printing plugin on your OS.',
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
