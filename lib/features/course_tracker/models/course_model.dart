import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing an online course tracked in Focusly.
///
/// Firestore path: `users/{userId}/courses/{courseId}` (isolated per-user).
class CourseModel {
  final String id;
  final String title;
  final String? platform; // e.g. Udemy, Coursera, YouTube, Frontend Masters
  final int totalLessons; // Minimum 1, default 10
  final int completedLessons; // Clamped between 0 and totalLessons
  final String status; // 'active' | 'paused' | 'completed'
  final bool certificate; // Whether a certificate was obtained
  final String? note; // Optional short notes/takeaways
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseModel({
    required this.id,
    required this.title,
    this.platform,
    this.totalLessons = 10,
    this.completedLessons = 0,
    this.status = 'active',
    this.certificate = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress percentage integer (0..100).
  int get progressPercent {
    if (totalLessons <= 0) return 0;
    final pct = (completedLessons / totalLessons * 100).round();
    return pct.clamp(0, 100);
  }

  /// Whether all lessons in the course have been completed.
  bool get isCompleted => totalLessons > 0 && completedLessons >= totalLessons;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'platform': platform,
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'status': status,
      'certificate': certificate,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CourseModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawTotal = (map['totalLessons'] as num?)?.toInt() ?? 10;
    final total = rawTotal > 0 ? rawTotal : 1;

    final rawCompleted = (map['completedLessons'] as num?)?.toInt() ?? 0;
    final completed = rawCompleted.clamp(0, total);

    return CourseModel(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      platform: (map['platform'] as String?)?.trim(),
      totalLessons: total,
      completedLessons: completed,
      status:
          (map['status'] as String?)?.trim() ??
          (completed >= total ? 'completed' : 'active'),
      certificate: map['certificate'] ?? false,
      note: (map['note'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  CourseModel copyWith({
    String? id,
    String? title,
    String? platform,
    int? totalLessons,
    int? completedLessons,
    String? status,
    bool? certificate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearPlatform = false,
    bool clearNote = false,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      platform: clearPlatform ? null : (platform ?? this.platform),
      totalLessons: totalLessons ?? this.totalLessons,
      completedLessons: completedLessons ?? this.completedLessons,
      status: status ?? this.status,
      certificate: certificate ?? this.certificate,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          platform == other.platform &&
          totalLessons == other.totalLessons &&
          completedLessons == other.completedLessons &&
          status == other.status &&
          certificate == other.certificate &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      (platform?.hashCode ?? 0) ^
      totalLessons.hashCode ^
      completedLessons.hashCode ^
      status.hashCode ^
      certificate.hashCode ^
      (note?.hashCode ?? 0);
}
