import '../models/knowledge_entry_model.dart';

/// Pure functions for Knowledge Base search, type filtering, and tag parsing.
///
/// Contains NO side effects or external dependencies for 100% deterministic testability.
class KnowledgeFilterHelper {
  /// Filters a list of [KnowledgeEntryModel] items by search [query] and [selectedType].
  ///
  /// Matching Rules:
  /// - [query]: Case-insensitive substring match against title, content, source, and all tags.
  /// - [selectedType]: If 'all', includes all types; otherwise matches exact entry type.
  static List<KnowledgeEntryModel> filterKnowledgeEntries({
    required List<KnowledgeEntryModel> entries,
    required String query,
    required String selectedType,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final isTypeFiltered = selectedType.isNotEmpty && selectedType.toLowerCase() != 'all';

    return entries.where((entry) {
      // 1. Type Match
      if (isTypeFiltered && entry.type.toLowerCase() != selectedType.toLowerCase()) {
        return false;
      }

      // 2. Query Match
      if (cleanQuery.isEmpty) return true;

      final matchesTitle = entry.title.toLowerCase().contains(cleanQuery);
      final matchesContent = entry.content.toLowerCase().contains(cleanQuery);
      final matchesSource = (entry.source?.toLowerCase() ?? '').contains(cleanQuery);
      final matchesTag = entry.tags.any((t) => t.toLowerCase().contains(cleanQuery));

      return matchesTitle || matchesContent || matchesSource || matchesTag;
    }).toList();
  }

  /// Parses a comma-separated string into a normalized list of tags.
  ///
  /// Strips whitespace, removes leading `#` characters, and filters out empty items.
  /// Example: "flutter, #dart, state-management , " -> ["flutter", "dart", "state-management"]
  static List<String> parseTags(String rawTags) {
    if (rawTags.trim().isEmpty) return const [];

    final Set<String> uniqueTags = {};
    final parts = rawTags.split(',');

    for (final part in parts) {
      var tag = part.trim();
      if (tag.startsWith('#')) {
        tag = tag.substring(1).trim();
      }
      if (tag.isNotEmpty) {
        uniqueTags.add(tag);
      }
    }

    return uniqueTags.toList();
  }
}
