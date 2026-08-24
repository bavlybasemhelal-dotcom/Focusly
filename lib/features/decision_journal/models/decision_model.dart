import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual Decision Journal entry.
///
/// Each decision records:
/// - [title]: Short, descriptive title of the decision.
/// - [date]: Date when the decision was made (defaults to today).
/// - [rationale]: Why the user made this decision (context, reasoning, alternatives).
/// - [expected]: Expected outcome or prediction at the time of making the decision.
/// - [outcome]: What actually happened when evaluated later.
/// - [reviewed]: Whether the decision has been reviewed / evaluated yet.
/// - [createdAt]: Timestamp when document was created.
/// - [updatedAt]: Timestamp when document was last modified.
///
/// Firestore path: `users/{userId}/decisions/{decisionId}` (per-user data isolation).
class DecisionModel {
  final String id;
  final String title;
  final DateTime date;
  final String rationale;
  final String expected;
  final String outcome;
  final bool reviewed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DecisionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.rationale,
    required this.expected,
    this.outcome = '',
    this.reviewed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Serializes the model into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': Timestamp.fromDate(date),
      'rationale': rationale,
      'expected': expected,
      'outcome': outcome,
      'reviewed': reviewed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore document snapshot into a [DecisionModel].
  factory DecisionModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedDate = parseDate(map['date'], now);
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    return DecisionModel(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      date: parsedDate,
      rationale: (map['rationale'] as String?)?.trim() ?? '',
      expected: (map['expected'] as String?)?.trim() ?? '',
      outcome: (map['outcome'] as String?)?.trim() ?? '',
      reviewed: (map['reviewed'] as bool?) ?? false,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this [DecisionModel] with modified fields.
  DecisionModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? rationale,
    String? expected,
    String? outcome,
    bool? reviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DecisionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      rationale: rationale ?? this.rationale,
      expected: expected ?? this.expected,
      outcome: outcome ?? this.outcome,
      reviewed: reviewed ?? this.reviewed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          date == other.date &&
          rationale == other.rationale &&
          expected == other.expected &&
          outcome == other.outcome &&
          reviewed == other.reviewed;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      date.hashCode ^
      rationale.hashCode ^
      expected.hashCode ^
      outcome.hashCode ^
      reviewed.hashCode;
}
