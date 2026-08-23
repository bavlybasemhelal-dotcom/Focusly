import 'package:flutter/material.dart';

/// Model representing a Schedule event category/type with an assigned palette color.
class EventType {
  final String id;
  final String nameKey;
  final int colorValue;
  final bool isDefault;

  const EventType({
    required this.id,
    required this.nameKey,
    required this.colorValue,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameKey': nameKey,
      'colorValue': colorValue,
      'isDefault': isDefault,
    };
  }

  factory EventType.fromMap(Map<String, dynamic> map, String docId) {
    return EventType(
      id: docId,
      nameKey: map['nameKey'] ?? map['name'] ?? 'type_personal',
      colorValue: map['colorValue'] is int
          ? map['colorValue']
          : const Color(0xFF2563EB).toARGB32(),
      isDefault: map['isDefault'] ?? false,
    );
  }

  /// Default seeded event types with distinct colors from Focusly's design system
  static const List<EventType> defaultEventTypes = [
    EventType(
      id: 'course_study',
      nameKey: 'type_course_study',
      colorValue: 0xFF8B5CF6, // Royal Violet / Purple
      isDefault: true,
    ),
    EventType(
      id: 'training_sport',
      nameKey: 'type_training_sport',
      colorValue: 0xFF10B981, // Vibrant Emerald
      isDefault: true,
    ),
    EventType(
      id: 'work_meeting',
      nameKey: 'type_work_meeting',
      colorValue: 0xFF2563EB, // Royal Blue
      isDefault: true,
    ),
    EventType(
      id: 'personal',
      nameKey: 'type_personal',
      colorValue: 0xFFEC4899, // Rose Pink
      isDefault: true,
    ),
    EventType(
      id: 'exam',
      nameKey: 'type_exam',
      colorValue: 0xFFEF4444, // Error / Urgent Red
      isDefault: true,
    ),
    EventType(
      id: 'important_urgent',
      nameKey: 'type_important_urgent',
      colorValue: 0xFFF59E0B, // Amber Gold
      isDefault: true,
    ),
  ];
}
