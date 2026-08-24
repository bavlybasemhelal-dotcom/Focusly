import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/social_battery_helpers.dart';
import '../models/social_battery_entry_model.dart';
import '../services/social_battery_service.dart';

/// Provider exposing SocialBatteryService singleton.
final socialBatteryServiceProvider = Provider<SocialBatteryService>((ref) {
  return SocialBatteryService();
});

/// Stream provider for all Social Battery entries for the authenticated user.
///
/// Strictly scoped to `users/{uid}/socialBattery`.
final socialBatteryStreamProvider =
    StreamProvider<List<SocialBatteryEntryModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(socialBatteryServiceProvider);
  return service.streamEntries(uid);
});

/// Derived provider: The 10 most recent entries in reverse-chronological order.
final recentSocialBatteryLogsProvider =
    Provider<List<SocialBatteryEntryModel>>((ref) {
  final entries = ref.watch(socialBatteryStreamProvider).value ?? [];
  return entries.take(10).toList();
});

/// Derived provider: Computed summary metrics (net energy balance, energizer/drainer counts).
final socialBatterySummaryProvider = Provider<SocialBatterySummary>((ref) {
  final entries = ref.watch(socialBatteryStreamProvider).value ?? [];
  return SocialBatteryHelpers.calculateSummary(entries);
});
