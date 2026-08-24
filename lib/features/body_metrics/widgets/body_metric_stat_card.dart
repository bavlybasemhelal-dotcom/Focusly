import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Stat card widget displaying an individual body metric reading.
class BodyMetricStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final String? dateSubtitle;

  const BodyMetricStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.dateSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final secondaryTextColor = AppColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon and Label
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Value
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Optional Date Subtitle
          if (dateSubtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              dateSubtitle!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
