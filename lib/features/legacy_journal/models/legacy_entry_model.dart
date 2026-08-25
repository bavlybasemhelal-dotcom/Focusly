import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a deep personal reflection entry in Focusly's Legacy Journal.
///
/// Types:
/// - `'letter'`: Letter to Future Self
/// - `'value'`: Core Personal Value / Belief
/// - `'will'`: Will / Philosophy Guideline
class LegacyEntryModel {
  final String id;
  final String title;
  final DateTime date;
  final String type; // 'letter' | 'value' | 'will'
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LegacyEntryModel({
    required this.id,
    required this.title,
    required this.date,
    this.type = 'letter',
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLetter => type == 'letter';
  bool get isValue => type == 'value';
  bool get isWill => type == 'will';

  /// Formatted date string (e.g. "Aug 25, 2026")
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Converts model to Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Factory constructor from Firestore document snapshot
  factory LegacyEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LegacyEntryModel.fromMap(data, doc.id);
  }

  /// Factory constructor from Map and docId
  factory LegacyEntryModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate = DateTime.now();
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date'] as String) ?? DateTime.now();
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
    }

    DateTime parsedUpdatedAt = DateTime.now();
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt = DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now();
    }

    return LegacyEntryModel(
      id: docId,
      title: map['title'] as String? ?? '',
      date: parsedDate,
      type: map['type'] as String? ?? 'letter',
      content: map['content'] as String? ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this model with optional updated values
  LegacyEntryModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? type,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LegacyEntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      type: type ?? this.type,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
