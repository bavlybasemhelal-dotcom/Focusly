import 'package:flutter/material.dart';
import '../../contacts/models/contact_model.dart';
import '../models/relationship_log_model.dart';

enum RecencyCategory {
  never, // Zero recorded interactions
  recent, // <= 14 days (Green)
  moderate, // 15..30 days (Amber)
  overdue, // > 30 days (Red)
}

/// Helper container describing how recently a contact was reached out to.
class RecencyInfo {
  final RecencyCategory category;
  final int? days; // null if never contacted
  final DateTime? lastDate;

  const RecencyInfo({required this.category, this.days, this.lastDate});

  Color get badgeColor {
    switch (category) {
      case RecencyCategory.never:
      case RecencyCategory.overdue:
        return const Color(0xFFEF4444); // Red
      case RecencyCategory.moderate:
        return const Color(0xFFF59E0B); // Amber
      case RecencyCategory.recent:
        return const Color(0xFF10B981); // Green
    }
  }
}

/// Pure helper functions for computing contact interaction recency.
class RelationshipHealthHelpers {
  /// Computes the recency classification for a given [contact] based on logged interactions.
  ///
  /// Threshold logic:
  /// - If no logs exist for this contact -> [RecencyCategory.never].
  /// - If days <= 14 -> [RecencyCategory.recent] (Green).
  /// - If 15 <= days <= 30 -> [RecencyCategory.moderate] (Amber).
  /// - If days > 30 -> [RecencyCategory.overdue] (Red).
  static RecencyInfo computeRecency(
    ContactModel contact,
    List<RelationshipLogModel> allLogs, [
    DateTime? now,
  ]) {
    final contactLogs = allLogs
        .where((l) => l.contactId == contact.id)
        .toList();

    if (contactLogs.isEmpty) {
      return const RecencyInfo(category: RecencyCategory.never);
    }

    // Sort by date descending to find the latest
    contactLogs.sort((a, b) => b.date.compareTo(a.date));
    final latestDate = contactLogs.first.date;
    final days = daysSinceLastContact(latestDate, now);

    if (days <= 14) {
      return RecencyInfo(
        category: RecencyCategory.recent,
        days: days,
        lastDate: latestDate,
      );
    } else if (days <= 30) {
      return RecencyInfo(
        category: RecencyCategory.moderate,
        days: days,
        lastDate: latestDate,
      );
    } else {
      return RecencyInfo(
        category: RecencyCategory.overdue,
        days: days,
        lastDate: latestDate,
      );
    }
  }
}
