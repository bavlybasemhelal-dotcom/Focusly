import '../../../core/data/calendar_clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// TODO: Relationship Health feature will build directly on this same overdue-calculation logic.

/// Pure helper calculating full calendar days since last contact date.
int daysSinceLastContact(DateTime lastContact, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final todayStart = DateTime(current.year, current.month, current.day);
  final contactStart = DateTime(
    lastContact.year,
    lastContact.month,
    lastContact.day,
  );
  final diff = calendarDaysBetween(contactStart, todayStart);
  return diff < 0 ? 0 : diff;
}

/// Pure helper determining whether a contact is due or overdue for reconnection.
bool isContactOverdue(DateTime lastContact, int remindDays, [DateTime? now]) {
  return daysSinceLastContact(lastContact, now) >= remindDays;
}

/// Pure helper returning how many days a contact has been overdue beyond the reminder interval.
int overdueDaysCount(DateTime lastContact, int remindDays, [DateTime? now]) {
  final days = daysSinceLastContact(lastContact, now);
  final diff = days - remindDays;
  return diff > 0 ? diff : 0;
}

/// Data model representing a personal relationship / contact in Focusly.
///
/// Stored in Firestore under: `users/{userId}/contacts/{contactId}`
class ContactModel {
  final bool hasContacted;
  final String id;
  final String name;
  final String emoji; // Avatar emoji, default 🙂
  final String? role; // e.g. "College friend", "Mentor", "Cousin"
  final String? contactInfo; // Free-text phone/email/handle
  final DateTime lastContact; // Date of last interaction
  final int
  remindDays; // Interval in days before contact is considered due (default 30)
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactModel({
    required this.id,
    this.hasContacted = true,
    required this.name,
    this.emoji = '🙂',
    this.role,
    this.contactInfo,
    required this.lastContact,
    this.remindDays = 30,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computed days elapsed since last contact
  int get daysSinceLast => daysSinceLastContact(lastContact);

  /// Computed boolean indicating if reconnection is due/overdue
  bool get isDue => !hasContacted || isContactOverdue(lastContact, remindDays);

  /// Number of days overdue beyond remind interval
  int get overdueByDays => overdueDaysCount(lastContact, remindDays);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hasContacted': hasContacted,
      'name': name,
      'emoji': emoji,
      'role': role,
      'contactInfo': contactInfo,
      'lastContact': Timestamp.fromDate(lastContact),
      'remindDays': remindDays,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedLastContact;
    if (map['lastContact'] is Timestamp) {
      parsedLastContact = (map['lastContact'] as Timestamp).toDate();
    } else if (map['lastContact'] is String) {
      parsedLastContact =
          DateTime.tryParse(map['lastContact']) ?? DateTime.now();
    } else {
      parsedLastContact = DateTime.now();
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime parsedUpdatedAt;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt = DateTime.tryParse(map['updatedAt']) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    return ContactModel(
      id: docId,
      hasContacted: map['hasContacted'] as bool? ?? map['lastContact'] != null,
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '🙂',
      role: map['role'],
      contactInfo: map['contactInfo'],
      lastContact: parsedLastContact,
      remindDays: (map['remindDays'] as num?)?.toInt() ?? 30,
      notes: map['notes'],
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? emoji,
    String? role,
    String? contactInfo,
    DateTime? lastContact,
    int? remindDays,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearRole = false,
    bool clearContactInfo = false,
    bool clearNotes = false,
  }) {
    return ContactModel(
      id: id ?? this.id,
      hasContacted: hasContacted,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      role: clearRole ? null : (role ?? this.role),
      contactInfo: clearContactInfo ? null : (contactInfo ?? this.contactInfo),
      lastContact: lastContact ?? this.lastContact,
      remindDays: remindDays ?? this.remindDays,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          emoji == other.emoji &&
          lastContact == other.lastContact &&
          remindDays == other.remindDays;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      emoji.hashCode ^
      lastContact.hashCode ^
      remindDays.hashCode;
}
