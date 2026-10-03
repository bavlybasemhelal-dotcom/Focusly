import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Book in the Reading Tracker.
///
/// Shelves / Statuses:
/// - `reading`: Currently in-progress book.
/// - `paused`: Temporarily on hold.
/// - `wishlist`: Want-to-read book.
/// - `done`: Completed book.
///
/// Firestore path: `users/{userId}/books/{bookId}` (isolated per-user).
class BookModel {
  final String id;
  final String title;
  final String author;
  final int totalPages;
  final int currentPage;
  final String status; // 'reading' | 'paused' | 'wishlist' | 'done'
  final int coverColor; // Hex Color integer (e.g. 0xFF2E6FF2)
  final String?
  coverUrl; // Optional image URL (TODO: Image upload feature in future pass)
  final DateTime? startDate;
  final DateTime? finishDate;
  final int? rating; // 1-5 stars (only when status == 'done')
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.totalPages = 200,
    this.currentPage = 0,
    this.status = 'reading',
    this.coverColor = 0xFF2E6FF2,
    this.coverUrl,
    this.startDate,
    this.finishDate,
    this.rating,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculates reading progress percentage (0..100).
  int get progressPercent {
    if (totalPages <= 0) return 0;
    final pct = (currentPage / totalPages * 100).round();
    return pct.clamp(0, 100);
  }

  /// Whether the book is marked as completed.
  bool get isFinished => status == 'done';

  /// Whether the book is on the active Reading shelf (reading or paused).
  bool get isReadingShelf => status == 'reading' || status == 'paused';

  /// Whether the book is on the Wishlist shelf.
  bool get isWishlist => status == 'wishlist';

  /// Serializes model to Firestore document map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'status': status,
      'coverColor': coverColor,
      'coverUrl': coverUrl,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'finishDate': finishDate != null ? Timestamp.fromDate(finishDate!) : null,
      'rating': rating,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore snapshot map into a [BookModel].
  factory BookModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawTotal = (map['totalPages'] as num?)?.toInt() ?? 200;
    final total = rawTotal > 0 ? rawTotal : 1;
    final rawCurrent = (map['currentPage'] as num?)?.toInt() ?? 0;
    final current = rawCurrent.clamp(0, total);

    return BookModel(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      author: (map['author'] as String?)?.trim() ?? '',
      totalPages: total,
      currentPage: current,
      status: (map['status'] as String?)?.trim() ?? 'reading',
      coverColor: (map['coverColor'] as num?)?.toInt() ?? 0xFF2E6FF2,
      coverUrl: map['coverUrl'] as String?,
      startDate: parseNullableDate(map['startDate']),
      finishDate: parseNullableDate(map['finishDate']),
      rating: (map['rating'] as num?)?.toInt(),
      notes: (map['notes'] as String?)?.trim() ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this [BookModel] with modified fields.
  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    int? totalPages,
    int? currentPage,
    String? status,
    int? coverColor,
    String? coverUrl,
    DateTime? startDate,
    DateTime? finishDate,
    int? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFinishDate = false,
    bool clearRating = false,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      status: status ?? this.status,
      coverColor: coverColor ?? this.coverColor,
      coverUrl: coverUrl ?? this.coverUrl,
      startDate: startDate ?? this.startDate,
      finishDate: clearFinishDate ? null : (finishDate ?? this.finishDate),
      rating: clearRating ? null : (rating ?? this.rating),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          totalPages == other.totalPages &&
          currentPage == other.currentPage &&
          status == other.status &&
          coverColor == other.coverColor &&
          coverUrl == other.coverUrl &&
          rating == other.rating;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      author.hashCode ^
      totalPages.hashCode ^
      currentPage.hashCode ^
      status.hashCode ^
      coverColor.hashCode ^
      (coverUrl?.hashCode ?? 0) ^
      (rating?.hashCode ?? 0);
}
