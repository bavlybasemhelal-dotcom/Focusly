import '../models/social_battery_entry_model.dart';

/// Summary metrics computed from a list of Social Battery log entries.
class SocialBatterySummary {
  final int netEnergyBalance; // sum(energizers) - sum(drainers)
  final int energizersCount;
  final int drainersCount;
  final int totalEnergizerImpact;
  final int totalDrainerImpact;

  const SocialBatterySummary({
    required this.netEnergyBalance,
    required this.energizersCount,
    required this.drainersCount,
    required this.totalEnergizerImpact,
    required this.totalDrainerImpact,
  });

  /// Formatted signed string for display (e.g., "+7", "-4", "0").
  String get formattedBalance {
    if (netEnergyBalance > 0) return '+$netEnergyBalance';
    return '$netEnergyBalance';
  }
}

/// Pure helper functions for Social Battery aggregations.
class SocialBatteryHelpers {
  /// Computes the net energy balance and counts from a list of entries.
  static SocialBatterySummary calculateSummary(List<SocialBatteryEntryModel> entries) {
    int energizersCount = 0;
    int drainersCount = 0;
    int totalEnergizerImpact = 0;
    int totalDrainerImpact = 0;

    for (final entry in entries) {
      if (entry.isEnergizer) {
        energizersCount++;
        totalEnergizerImpact += entry.impact;
      } else {
        drainersCount++;
        totalDrainerImpact += entry.impact;
      }
    }

    final netBalance = totalEnergizerImpact - totalDrainerImpact;

    return SocialBatterySummary(
      netEnergyBalance: netBalance,
      energizersCount: energizersCount,
      drainersCount: drainersCount,
      totalEnergizerImpact: totalEnergizerImpact,
      totalDrainerImpact: totalDrainerImpact,
    );
  }
}
