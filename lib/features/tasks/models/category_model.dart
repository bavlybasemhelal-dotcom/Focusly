import 'package:flutter/material.dart';

/// Model representing a task category tag with a custom or preset color.
class TaskCategory {
  final String id;
  final String nameKey;
  final int colorValue;
  final bool isDefault;

  const TaskCategory({
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

  factory TaskCategory.fromMap(Map<String, dynamic> map, String docId) {
    return TaskCategory(
      id: docId,
      nameKey: map['nameKey'] ?? map['name'] ?? 'category_personal',
      colorValue: map['colorValue'] is int
          ? map['colorValue']
          : const Color(0xFF3B82F6).toARGB32(),
      isDefault: map['isDefault'] ?? false,
    );
  }

  /// Default seeded categories with distinct palette colors from Focusly's design system
  static const List<TaskCategory> defaultCategories = [
    TaskCategory(
      id: 'work',
      nameKey: 'category_work',
      colorValue: 0xFF2563EB, // Primary Royal Blue
      isDefault: true,
    ),
    TaskCategory(
      id: 'study',
      nameKey: 'category_study',
      colorValue: 0xFF8B5CF6, // Royal Violet
      isDefault: true,
    ),
    TaskCategory(
      id: 'health',
      nameKey: 'category_health',
      colorValue: 0xFF10B981, // Vibrant Emerald
      isDefault: true,
    ),
    TaskCategory(
      id: 'personal',
      nameKey: 'category_personal',
      colorValue: 0xFFEC4899, // Rose Pink
      isDefault: true,
    ),
    TaskCategory(
      id: 'courses',
      nameKey: 'category_courses',
      colorValue: 0xFF0EA5E9, // Sky Blue
      isDefault: true,
    ),
    TaskCategory(
      id: 'training',
      nameKey: 'category_training',
      colorValue: 0xFFF59E0B, // Amber Gold
      isDefault: true,
    ),
  ];
}
