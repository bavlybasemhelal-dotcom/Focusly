import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/budget_models.dart';
import 'providers/budget_provider.dart';
import 'widgets/budget_config_modal.dart';
import 'widgets/transaction_form_modal.dart';

/// Main Budget Tracker screen displaying this month's stats, recent transactions,
/// category spending limits with visual progress bars, and empty states.
class BudgetTrackerPage extends ConsumerWidget {
  const BudgetTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final transactionsAsync = ref.watch(budgetTransactionsStreamProvider);
    final configAsync = ref.watch(budgetConfigStreamProvider);
    final summary = ref.watch(thisMonthSummaryProvider);
    final recentTx = ref.watch(recentTransactionsProvider);
    final categoryLimits = ref.watch(categoryLimitProgressListProvider);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('budget_tracker_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('budget_tracker_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF6366F1),
            ),
            tooltip: context.tr('add_transaction_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              TransactionFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          context.tr('add_transaction_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          TransactionFormModal.show(context);
        },
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (allTransactions) {
          // Zero transactions empty state
          if (allTransactions.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: isDark ? 0.15 : 0.1),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('💰', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('budget_empty_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        context.tr('budget_empty_subtitle'),
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        context.tr('add_transaction_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        TransactionFormModal.show(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Main Layout
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =========================================================
              // 1. THIS-MONTH STAT ROW (Income, Expenses, Balance)
              // =========================================================
              Row(
                children: [
                  // Income Stat
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      label: context.tr('budget_income'),
                      value: summary.formatCurrency(summary.totalIncome),
                      icon: Icons.arrow_upward_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expenses Stat
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      label: context.tr('budget_expenses'),
                      value: summary.formatCurrency(summary.totalExpenses),
                      icon: Icons.arrow_downward_rounded,
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Balance Stat
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      label: context.tr('budget_balance'),
                      value: summary.formatCurrency(
                        summary.balance,
                        showSign: summary.balance < 0,
                      ),
                      icon: Icons.account_balance_wallet_rounded,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF6366F1),
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // =========================================================
              // 2. BUDGET LIMITS CARD
              // =========================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Configure Limits button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.pie_chart_rounded,
                                  size: 18,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('budget_limits_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: Text(
                            context.tr('configure_limits_btn'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            final config =
                                configAsync.value ?? const BudgetConfigModel();
                            BudgetConfigModal.show(
                              context,
                              initialConfig: config,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (categoryLimits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            context.tr('budget_config_subtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categoryLimits.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = categoryLimits[index];
                          final spentStr = '\$${item.spent.toStringAsFixed(2)}';
                          final limitStr = item.hasLimit
                              ? '\$${item.limit!.toStringAsFixed(2)}'
                              : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.category.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.tr(item.category.labelKey),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    item.hasLimit
                                        ? '$spentStr / $limitStr'
                                        : spentStr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: item.hasLimit
                                          ? item.statusColor
                                          : primaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.hasLimit) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: item.progressFraction,
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      item.statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // =========================================================
              // 3. RECENT TRANSACTIONS LIST (10 most recent)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('recent_transactions'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTx.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        height: 16,
                      ),
                      itemBuilder: (context, index) {
                        final tx = recentTx[index];
                        final cat = BudgetCategory.find(tx.category, tx.type);
                        final dateStr =
                            '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
                        final displayTitle =
                            tx.note != null && tx.note!.isNotEmpty
                            ? tx.note!
                            : context.tr(cat.labelKey);

                        final amountStr = tx.isIncome
                            ? '+\$${tx.amount.toStringAsFixed(2)}'
                            : '-\$${tx.amount.toStringAsFixed(2)}';
                        final amountColor = tx.isIncome
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444);

                        return Row(
                          children: [
                            // Category Icon Circle
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color:
                                    (tx.isIncome
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444))
                                        .withValues(alpha: isDark ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  cat.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Note / Category Title & Sub-line
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dateStr • ${context.tr(cat.labelKey)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Amount Right-aligned
                            Text(
                              amountStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: amountColor,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Edit Icon Action
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: secondaryTextColor,
                              ),
                              tooltip: context.tr('edit'),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                TransactionFormModal.show(
                                  context,
                                  transaction: tx,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Icon(icon, size: 14, color: color)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
