import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a single Social Battery log entry.
///
/// Firestore path: `users/{userId}/socialBattery/{entryId}` (isolated per-user).
class SocialBatteryEntryModel {
  final String id;
  final String name; // Person's name or event title
  final String type; // 'energizer' or 'drainer'
  final int impact; // Magnitude 1 to 5 (default 3)
  final DateTime date;
  final String? notes; // Optional short takeaway notes
  final DateTime createdAt;
  final DateTime updatedAt;

  const SocialBatteryEntryModel({
    required this.id,
    required this.name,
    required this.type,
    this.impact = 3,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEnergizer => type == 'energizer';
  bool get isDrainer => type == 'drainer';

  /// Signed impact value (+impact for energizers, -impact for drainers).
  int get signedImpact => isEnergizer ? impact : -impact;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'impact': impact,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SocialBatteryEntryModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedDate = parseDate(map['date'], now);
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawType =
        (map['type'] as String?)?.toLowerCase().trim() ?? 'energizer';
    final type = (rawType == 'drainer') ? 'drainer' : 'energizer';

    final rawImpact = (map['impact'] as num?)?.toInt() ?? 3;
    final impact = rawImpact.clamp(1, 5);

    return SocialBatteryEntryModel(
      id: docId,
      name: (map['name'] as String?)?.trim() ?? '',
      type: type,
      impact: impact,
      date: parsedDate,
      notes: (map['notes'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  SocialBatteryEntryModel copyWith({
    String? id,
    String? name,
    String? type,
    int? impact,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNotes = false,
  }) {
    return SocialBatteryEntryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      impact: impact ?? this.impact,
      date: date ?? this.date,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialBatteryEntryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          impact == other.impact &&
          date == other.date &&
          notes == other.notes;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      impact.hashCode ^
      date.hashCode ^
      (notes?.hashCode ?? 0);
}
