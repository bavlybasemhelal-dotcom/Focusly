import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import '../models/legacy_entry_model.dart';
import '../services/legacy_journal_service.dart';

/// Provider exposing the Firestore service for Legacy Journal
final legacyJournalServiceProvider = Provider<LegacyJournalService>((ref) {
  return LegacyJournalService();
});

/// Real-time stream of all Legacy Journal entries for the active authenticated user
final legacyJournalStreamProvider =
    StreamProvider.autoDispose<List<LegacyEntryModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(<LegacyEntryModel>[]);
  }
  final service = ref.watch(legacyJournalServiceProvider);
  return service.getEntriesStream(uid);
});

/// Filtered provider for Letters to Future Self (type='letter')
final letterEntriesProvider =
    Provider.autoDispose<List<LegacyEntryModel>>((ref) {
  final allEntries = ref.watch(legacyJournalStreamProvider).value ?? [];
  return allEntries.where((e) => e.isLetter).toList();
});

/// Filtered provider for Core Values & Beliefs (type='value')
final valueEntriesProvider =
    Provider.autoDispose<List<LegacyEntryModel>>((ref) {
  final allEntries = ref.watch(legacyJournalStreamProvider).value ?? [];
  return allEntries.where((e) => e.isValue).toList();
});

/// Filtered provider for Will & Philosophy Guidelines (type='will')
final willEntriesProvider =
    Provider.autoDispose<List<LegacyEntryModel>>((ref) {
  final allEntries = ref.watch(legacyJournalStreamProvider).value ?? [];
  return allEntries.where((e) => e.isWill).toList();
});
