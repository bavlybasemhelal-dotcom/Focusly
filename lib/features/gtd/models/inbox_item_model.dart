import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a raw captured thought in GTD Inbox (`users/{uid}/inbox/{itemId}`).
///
/// Kept lightweight to minimize friction during capture.
class InboxItemModel {
  final String id;
  final String text;
  final bool processed;
  final DateTime createdAt;

  const InboxItemModel({
    required this.id,
    required this.text,
    this.processed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'processed': processed,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InboxItemModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return InboxItemModel(
      id: docId,
      text: map['text'] ?? '',
      processed: map['processed'] ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  InboxItemModel copyWith({
    String? id,
    String? text,
    bool? processed,
    DateTime? createdAt,
  }) {
    return InboxItemModel(
      id: id ?? this.id,
      text: text ?? this.text,
      processed: processed ?? this.processed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
