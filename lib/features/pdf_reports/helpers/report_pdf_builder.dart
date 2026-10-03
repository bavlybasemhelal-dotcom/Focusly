import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import '../models/report_models.dart';

/// PDF document generation engine constructing high-fidelity print-styled
/// productivity reports with charts, gauges, and statistics.
class ReportPdfBuilder {
  /// Builds the complete printable/shareable PDF document.
  static Future<Uint8List> buildReportPdf({
    required ReportData data,
    required AppLocalizations localizations,
    bool isArabic = false,
  }) async {
    final pdf = pw.Document();

    // Bundled SIL Open Font License fonts work without network access.
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final fontMedium = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Medium.ttf'),
    );

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      fontFallback: [fontRegular, fontMedium],
    );

    // Color definitions
    const primaryColor = PdfColor.fromInt(0xFF6366F1); // Indigo
    const textColorPrimary = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const textColorSecondary = PdfColor.fromInt(0xFF64748B); // Slate 500
    const cardBgColor = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const borderColor = PdfColor.fromInt(0xFFE2E8F0); // Slate 200

    final scoreTierColor = PdfColor.fromInt(data.score.tierColorHex);

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateRangeStr =
        '${months[data.startDate.month - 1]} ${data.startDate.day}, ${data.startDate.year} - ${months[data.endDate.month - 1]} ${data.endDate.day}, ${data.endDate.year}';

    final textDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) {
          return pw.Directionality(
            textDirection: textDir,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // =============================================================
                // 1. HEADER
                // =============================================================
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: borderColor, width: 1.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Row(
                        children: [
                          // App Logo Icon Ring Mark
                          pw.Container(
                            width: 38,
                            height: 38,
                            decoration: const pw.BoxDecoration(
                              color: primaryColor,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                'F',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                localizations.tr('app_name'),
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textColorPrimary,
                                ),
                              ),
                              pw.Text(
                                localizations.tr(data.rangeOption.titleKey),
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            dateRangeStr,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: textColorPrimary,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Generated ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: textColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // =============================================================
                // 2. PRODUCTIVITY GAUGE & SUB-SCORES
                // =============================================================
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    color: cardBgColor,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(14),
                    ),
                    border: pw.Border.all(color: borderColor),
                  ),
                  child: pw.Row(
                    children: [
                      // Score Gauge Box
                      pw.Container(
                        width: 90,
                        height: 90,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: scoreTierColor,
                            width: 6,
                          ),
                          color: PdfColors.white,
                        ),
                        child: pw.Center(
                          child: pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                '${data.score.overallScore}',
                                style: pw.TextStyle(
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                  color: scoreTierColor,
                                ),
                              ),
                              pw.Text(
                                '/ 100',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: textColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 18),

                      // Score Breakdown Progress Bars
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  localizations.tr(data.score.tierKey),
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color: scoreTierColor,
                                  ),
                                ),
                                pw.Text(
                                  'Score: ${data.score.overallScore}%',
                                  style: const pw.TextStyle(
                                    fontSize: 12,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),

                            // Tasks Progress Bar (30%)
                            _buildSubScoreBar(
                              label: localizations.tr('report_task_completion'),
                              score: data.score.taskScore,
                              color: const PdfColor.fromInt(0xFF10B981),
                            ),
                            pw.SizedBox(height: 6),

                            // Focus Hours Progress Bar (30%)
                            _buildSubScoreBar(
                              label: localizations.tr('report_focus_hours'),
                              score: data.score.focusScore,
                              color: const PdfColor.fromInt(0xFF06B6D4),
                            ),
                            pw.SizedBox(height: 6),

                            // Habit Discipline Progress Bar (30%)
                            _buildSubScoreBar(
                              label: localizations.tr(
                                'report_habit_discipline',
                              ),
                              score: data.score.habitsScore,
                              color: const PdfColor.fromInt(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // =============================================================
                // 3. SUMMARY STATS (2x3 GRID)
                // =============================================================
                pw.Text(
                  localizations.tr('report_summary_stats'),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: textColorPrimary,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  children: [
                    _buildStatCard(
                      title: localizations.tr('stat_tasks_completed'),
                      value: '${data.completedTasksCount}',
                      color: const PdfColor.fromInt(0xFF10B981),
                    ),
                    pw.SizedBox(width: 8),
                    _buildStatCard(
                      title: localizations.tr('stat_tasks_pending'),
                      value: '${data.pendingTasksCount}',
                      color: const PdfColor.fromInt(0xFF64748B),
                    ),
                    pw.SizedBox(width: 8),
                    _buildStatCard(
                      title: localizations.tr('stat_completion_rate'),
                      value: '${data.completionRatePercent}%',
                      color: const PdfColor.fromInt(0xFF6366F1),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    _buildStatCard(
                      title: localizations.tr('stat_events_logged'),
                      value: '${data.eventsCount}',
                      color: const PdfColor.fromInt(0xFF06B6D4),
                    ),
                    pw.SizedBox(width: 8),
                    _buildStatCard(
                      title: localizations.tr('stat_total_focus_time'),
                      value: data.formattedFocusTime,
                      color: const PdfColor.fromInt(0xFF8B5CF6),
                    ),
                    pw.SizedBox(width: 8),
                    _buildStatCard(
                      title: localizations.tr('stat_avg_distractions'),
                      value: data.avgDistractionsPerSession.toStringAsFixed(1),
                      color: const PdfColor.fromInt(0xFFF59E0B),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // =============================================================
                // 4. TASK CATEGORY BREAKDOWN (IF ANY COMPLETED TASKS)
                // =============================================================
                if (data.categoryStats.isNotEmpty) ...[
                  pw.Text(
                    localizations.tr('report_category_breakdown'),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: textColorPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: cardBgColor,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      children: data.categoryStats.map((stat) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                width: 10,
                                height: 10,
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromInt(stat.colorValue),
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                flex: 4,
                                child: pw.Text(
                                  localizations.tr(stat.categoryName),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textColorPrimary,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '${stat.count} tasks',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: textColorSecondary,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '${stat.percentage.toStringAsFixed(1)}%',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textColorPrimary,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],

                // =============================================================
                // 5. TREND OVERVIEW
                // =============================================================
                pw.Text(
                  localizations.tr('report_trend_overview'),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: textColorPrimary,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: cardBgColor,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(12),
                    ),
                    border: pw.Border.all(color: borderColor),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: data.trendPoints.take(12).map((point) {
                      final taskBarHeight = (point.tasksCompleted * 6.0).clamp(
                        4.0,
                        40.0,
                      );
                      return pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 14,
                            height: taskBarHeight,
                            decoration: const pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: pw.BorderRadius.vertical(
                                top: pw.Radius.circular(4),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            point.label,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: textColorSecondary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                pw.Spacer(),

                // =============================================================
                // 6. FOOTER
                // =============================================================
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        localizations.tr('footer_generated_by'),
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: textColorSecondary,
                        ),
                      ),
                      pw.Text(
                        'Focusly - ${data.rangeOption.name.toUpperCase()}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSubScoreBar({
    required String label,
    required int score,
    required PdfColor color,
  }) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF334155),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(
                height: 7,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
              ),
              pw.Container(
                height: 7,
                width: 180.0 * (score / 100.0).clamp(0.0, 1.0),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 32,
          child: pw.Text(
            '$score%',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatCard({
    required String title,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF64748B),
              ),
              maxLines: 1,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
