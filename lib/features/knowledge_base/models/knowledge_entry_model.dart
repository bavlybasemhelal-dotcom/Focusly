import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Data model representing an entry in the personal Knowledge Base.
///
/// Types:
/// - `note`: Standard note or markdown snippet.
/// - `idea`: Insight or brainstorming thought.
/// - `quote`: Notable quote or excerpt.
/// - `link`: Useful resource URL / reference.
/// - `summary`: Book or article synopsis.
///
/// Firestore path: `users/{userId}/knowledge/{entryId}` (isolated per-user).
class KnowledgeEntryModel {
  final String id;
  final String title;
  final String type; // 'note' | 'idea' | 'quote' | 'link' | 'summary'
  final String content; // Multiline content text
  final String? source; // Optional citation/origin
  final List<String> tags; // Categorization tags
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeEntryModel({
    required this.id,
    required this.title,
    this.type = 'note',
    required this.content,
    this.source,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'content': content,
      'source': source,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory KnowledgeEntryModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    List<String> tagsList = [];
    if (map['tags'] is List) {
      tagsList = (map['tags'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return KnowledgeEntryModel(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      type: (map['type'] as String?)?.trim() ?? 'note',
      content: (map['content'] as String?)?.trim() ?? '',
      source: (map['source'] as String?)?.trim(),
      tags: tagsList,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  KnowledgeEntryModel copyWith({
    String? id,
    String? title,
    String? type,
    String? content,
    String? source,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSource = false,
  }) {
    return KnowledgeEntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      source: clearSource ? null : (source ?? this.source),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeEntryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          type == other.type &&
          content == other.content &&
          source == other.source &&
          listEquals(tags, other.tags);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      type.hashCode ^
      content.hashCode ^
      (source?.hashCode ?? 0) ^
      tags.fold(0, (prev, elem) => prev ^ elem.hashCode);
}
