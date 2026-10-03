import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a single Body Metrics entry.
///
/// Firestore path: `users/{userId}/bodyMetrics/{metricId}` (isolated per-user).
/// Each measurement field (weight, BP, pulse) is independently optional.
class BodyMetricModel {
  final String id;
  final DateTime date;
  final double? weight; // Weight in kg (optional)
  final int? bpSystolic; // Blood pressure systolic in mmHg (optional)
  final int? bpDiastolic; // Blood pressure diastolic in mmHg (optional)
  final int? pulse; // Pulse / Heart rate in bpm (optional)
  final String? note; // Optional context or notes
  final DateTime createdAt;
  final DateTime updatedAt;

  const BodyMetricModel({
    required this.id,
    required this.date,
    this.weight,
    this.bpSystolic,
    this.bpDiastolic,
    this.pulse,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Checks if valid weight reading exists.
  bool get hasWeight => weight != null && weight! > 0;

  /// Checks if both systolic and diastolic are present and valid (paired validation).
  bool get hasCompleteBp =>
      bpSystolic != null &&
      bpDiastolic != null &&
      bpSystolic! > 0 &&
      bpDiastolic! > 0;

  /// Checks if valid pulse reading exists.
  bool get hasPulse => pulse != null && pulse! > 0;

  /// Checks if at least one measurement or note is present.
  bool get hasAnyMeasurement =>
      hasWeight ||
      hasCompleteBp ||
      hasPulse ||
      (note != null && note!.trim().isNotEmpty);

  /// Converts model to Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'weight': weight,
      'bpSystolic': bpSystolic,
      'bpDiastolic': bpDiastolic,
      'pulse': pulse,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes model from Firestore snapshot map.
  factory BodyMetricModel.fromMap(Map<String, dynamic> map, String docId) {
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

    final num? rawWeight = map['weight'] as num?;
    final num? rawSystolic = map['bpSystolic'] as num?;
    final num? rawDiastolic = map['bpDiastolic'] as num?;
    final num? rawPulse = map['pulse'] as num?;

    return BodyMetricModel(
      id: docId,
      date: parsedDate,
      weight: rawWeight?.toDouble(),
      bpSystolic: rawSystolic?.toInt(),
      bpDiastolic: rawDiastolic?.toInt(),
      pulse: rawPulse?.toInt(),
      note: (map['note'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Copies this instance with optional overrides.
  BodyMetricModel copyWith({
    String? id,
    DateTime? date,
    double? weight,
    int? bpSystolic,
    int? bpDiastolic,
    int? pulse,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearWeight = false,
    bool clearBp = false,
    bool clearPulse = false,
    bool clearNote = false,
  }) {
    return BodyMetricModel(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: clearWeight ? null : (weight ?? this.weight),
      bpSystolic: clearBp ? null : (bpSystolic ?? this.bpSystolic),
      bpDiastolic: clearBp ? null : (bpDiastolic ?? this.bpDiastolic),
      pulse: clearPulse ? null : (pulse ?? this.pulse),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyMetricModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          weight == other.weight &&
          bpSystolic == other.bpSystolic &&
          bpDiastolic == other.bpDiastolic &&
          pulse == other.pulse &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      (weight?.hashCode ?? 0) ^
      (bpSystolic?.hashCode ?? 0) ^
      (bpDiastolic?.hashCode ?? 0) ^
      (pulse?.hashCode ?? 0) ^
      (note?.hashCode ?? 0);
}
