import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single periodic 8-dimension Wheel of Life assessment in Focusly.
///
/// Dimensions are rated on a 1-10 integer scale:
/// - [career]: Professional fulfillment & progress
/// - [finance]: Financial health & money management
/// - [health]: Physical vitality & wellness
/// - [family]: Quality of family relationships
/// - [romance]: Romantic intimacy & partnership
/// - [growth]: Personal learning, mindset & skills
/// - [fun]: Recreation, play & leisure
/// - [environment]: Home space, work surroundings & physical environment
class LifeAreaAssessmentModel {
  final String id;
  final DateTime date;
  final int career;
  final int finance;
  final int health;
  final int family;
  final int romance;
  final int growth;
  final int fun;
  final int environment;
  final DateTime createdAt;

  const LifeAreaAssessmentModel({
    required this.id,
    required this.date,
    this.career = 5,
    this.finance = 5,
    this.health = 5,
    this.family = 5,
    this.romance = 5,
    this.growth = 5,
    this.fun = 5,
    this.environment = 5,
    required this.createdAt,
  });

  /// Average score across all 8 dimensions (1.0 to 10.0)
  double get averageScore {
    final sum = career + finance + health + family + romance + growth + fun + environment;
    return (sum / 8.0 * 10).round() / 10.0;
  }

  /// Converts the model to a Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'career': career,
      'finance': finance,
      'health': health,
      'family': family,
      'romance': romance,
      'growth': growth,
      'fun': fun,
      'environment': environment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Factory constructor parsing from a Firestore document snapshot
  factory LifeAreaAssessmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LifeAreaAssessmentModel.fromMap(data, doc.id);
  }

  /// Factory constructor parsing from a Map and docId
  factory LifeAreaAssessmentModel.fromMap(Map<String, dynamic> map, String docId) {
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

    return LifeAreaAssessmentModel(
      id: docId,
      date: parsedDate,
      career: (map['career'] as num?)?.toInt() ?? 5,
      finance: (map['finance'] as num?)?.toInt() ?? 5,
      health: (map['health'] as num?)?.toInt() ?? 5,
      family: (map['family'] as num?)?.toInt() ?? 5,
      romance: (map['romance'] as num?)?.toInt() ?? 5,
      growth: (map['growth'] as num?)?.toInt() ?? 5,
      fun: (map['fun'] as num?)?.toInt() ?? 5,
      environment: (map['environment'] as num?)?.toInt() ?? 5,
      createdAt: parsedCreatedAt,
    );
  }

  /// Creates a copy of this model with optional updated values
  LifeAreaAssessmentModel copyWith({
    String? id,
    DateTime? date,
    int? career,
    int? finance,
    int? health,
    int? family,
    int? romance,
    int? growth,
    int? fun,
    int? environment,
    DateTime? createdAt,
  }) {
    return LifeAreaAssessmentModel(
      id: id ?? this.id,
      date: date ?? this.date,
      career: career ?? this.career,
      finance: finance ?? this.finance,
      health: health ?? this.health,
      family: family ?? this.family,
      romance: romance ?? this.romance,
      growth: growth ?? this.growth,
      fun: fun ?? this.fun,
      environment: environment ?? this.environment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Formatted date string (e.g. "Aug 25, 2026")
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
