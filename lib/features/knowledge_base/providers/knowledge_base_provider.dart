import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/knowledge_filter_helper.dart';
import '../models/knowledge_entry_model.dart';
import '../services/knowledge_base_service.dart';

/// Provider for KnowledgeBaseService singleton.
final knowledgeBaseServiceProvider = Provider<KnowledgeBaseService>((ref) {
  return KnowledgeBaseService();
});

/// Stream provider for all knowledge entries belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/knowledge`.
final knowledgeEntriesStreamProvider =
    StreamProvider<List<KnowledgeEntryModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(knowledgeBaseServiceProvider);
  return service.streamEntries(uid);
});

/// Notifier for search query filter in Knowledge Base.
class KnowledgeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final knowledgeSearchQueryProvider =
    NotifierProvider<KnowledgeSearchQueryNotifier, String>(
  KnowledgeSearchQueryNotifier.new,
);

/// Notifier for type filter dropdown in Knowledge Base ('all' | 'note' | 'idea' | 'quote' | 'link' | 'summary').
class KnowledgeTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setType(String type) => state = type;
}

final knowledgeTypeFilterProvider =
    NotifierProvider<KnowledgeTypeFilterNotifier, String>(
  KnowledgeTypeFilterNotifier.new,
);

/// Derived provider returning filtered list of knowledge entries based on search & type filter.
final filteredKnowledgeEntriesProvider =
    Provider<List<KnowledgeEntryModel>>((ref) {
  final entries = ref.watch(knowledgeEntriesStreamProvider).value ?? [];
  final query = ref.watch(knowledgeSearchQueryProvider);
  final selectedType = ref.watch(knowledgeTypeFilterProvider);

  return KnowledgeFilterHelper.filterKnowledgeEntries(
    entries: entries,
    query: query,
    selectedType: selectedType,
  );
});
