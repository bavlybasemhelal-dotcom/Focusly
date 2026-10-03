import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/account_deletion/user_data_collections.dart';

class BackupPreview {
  const BackupPreview(this.records, this.skipped, this.duplicates);
  final List<Map<String, dynamic>> records;
  final int skipped;
  final int duplicates;
}

/// Versioned local files. Import never writes shared records, rewards or assignment locks.
class BackupService {
  BackupService(this.firestore);
  final FirebaseFirestore firestore;
  static const protectedCollections = {
    'stats',
    'xpLog',
    'completionEvents',
    'notificationLog',
    'templateRuns',
  };
  static const nestedCollections = {
    'skills': ['taskClaims', 'dailyProgress'],
  };

  static Object? encode(Object? value) {
    if (value is Timestamp) {
      return {r'$timestamp': value.toDate().toUtc().toIso8601String()};
    }
    if (value is GeoPoint) {
      return {
        r'$geo': [value.latitude, value.longitude],
      };
    }
    if (value is DocumentReference) return {r'$reference': value.path};
    if (value is Map) {
      return value.map((key, data) => MapEntry(key.toString(), encode(data)));
    }
    if (value is Iterable) return value.map(encode).toList();
    return value;
  }

  static Object? decode(Object? value) {
    if (value is Map) {
      if (value.length == 1 && value[r'$timestamp'] is String) {
        return Timestamp.fromDate(
          DateTime.parse(value[r'$timestamp'] as String),
        );
      }
      if (value.length == 1 && value[r'$geo'] is List) {
        final coordinates = value[r'$geo'] as List;
        if (coordinates.length != 2 ||
            coordinates.any((number) => number is! num)) {
          throw const FormatException('Invalid coordinates');
        }
        return GeoPoint(
          (coordinates[0] as num).toDouble(),
          (coordinates[1] as num).toDouble(),
        );
      }
      if (value.containsKey(r'$reference')) {
        throw const FormatException('Document references cannot be imported');
      }
      return value.map((key, data) => MapEntry(key.toString(), decode(data)));
    }
    if (value is List) return value.map(decode).toList();
    return value;
  }

  Future<String> export(String uid) async {
    final records = <Map<String, dynamic>>[];
    final user = firestore.collection('users').doc(uid);
    for (final name in kUserDataSubcollections) {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query = user
            .collection(name)
            .orderBy(FieldPath.documentId)
            .limit(150);
        if (cursor != null) query = query.startAfterDocument(cursor);
        final page = await query.get();
        if (page.docs.isEmpty) break;
        for (final doc in page.docs) {
          records.add({'path': '$name/${doc.id}', 'data': encode(doc.data())});
          for (final child in nestedCollections[name] ?? <String>[]) {
            DocumentSnapshot<Map<String, dynamic>>? childCursor;
            while (true) {
              Query<Map<String, dynamic>> childQuery = doc.reference
                  .collection(child)
                  .orderBy(FieldPath.documentId)
                  .limit(150);
              if (childCursor != null) {
                childQuery = childQuery.startAfterDocument(childCursor);
              }
              final children = await childQuery.get();
              if (children.docs.isEmpty) break;
              for (final record in children.docs) {
                records.add({
                  'path': '$name/${doc.id}/$child/${record.id}',
                  'data': encode(record.data()),
                });
              }
              childCursor = children.docs.last;
            }
          }
        }
        cursor = page.docs.last;
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'focusly-backup',
      'schemaVersion': 1,
      'uid': uid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': records,
    });
  }

  static BackupPreview preview(String raw, String uid) {
    if (raw.length > 50 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 50 MB');
    }
    final parsed = jsonDecode(raw);
    if (parsed is! Map ||
        parsed['format'] != 'focusly-backup' ||
        parsed['schemaVersion'] != 1 ||
        parsed['uid'] != uid ||
        parsed['records'] is! List) {
      throw const FormatException(
        'Invalid backup, unsupported version, or a different account',
      );
    }
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    var skipped = 0;
    var duplicates = 0;
    for (final record in parsed['records'] as List) {
      if (record is! Map ||
          record['path'] is! String ||
          record['data'] is! Map) {
        throw const FormatException('Invalid record');
      }
      final path = record['path'] as String;
      final parts = path.split('/');
      if (parts.length != 2 ||
          parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
          !kUserDataSubcollections.contains(parts[0]) ||
          protectedCollections.contains(parts[0])) {
        skipped++;
        continue;
      }
      if (!seen.add(path)) {
        duplicates++;
        continue;
      }
      final data = Map<String, dynamic>.from(decode(record['data']) as Map);
      if (data['locked'] == true ||
          data['assignedByGroupId'] != null ||
          data['groupAssignmentId'] != null) {
        skipped++;
        continue;
      }
      if (data.containsKey('uid') && data['uid'] != uid) {
        throw const FormatException('Record owner differs');
      }
      validate(parts[0], data);
      result.add({'path': path, 'data': data});
    }
    return BackupPreview(result, skipped, duplicates);
  }

  static void validate(String collection, Map<String, dynamic> data) {
    final title = data['title'] ?? data['name'];
    if (title != null &&
        (title is! String || title.trim().isEmpty || title.length > 500)) {
      throw const FormatException('Invalid title');
    }
    if (data['notes'] is String && (data['notes'] as String).length > 20000) {
      throw const FormatException('Notes are too long');
    }
    for (final key in [
      'amount',
      'hours',
      'weight',
      'currentCount',
      'totalPages',
      'currentPage',
      'energy',
      'sleep',
      'water',
    ]) {
      if (data[key] != null &&
          (data[key] is! num ||
              !(data[key] as num).isFinite ||
              (data[key] as num) < 0)) {
        throw FormatException('Invalid $key');
      }
    }
    if (collection == 'tasks' &&
        (data['done'] is! bool || data['date'] is! Timestamp)) {
      throw const FormatException('Invalid task');
    }
    if (collection == 'habits' &&
        (data['days'] is! List ||
            (data['days'] as List).length != 7 ||
            (data['days'] as List).any((day) => day is! bool))) {
      throw const FormatException('Invalid habit');
    }
  }

  /// Existing IDs are preserved and skipped; retrying an interrupted import is safe.
  Future<int> import(String uid, BackupPreview preview) async {
    var imported = 0;
    for (final record in preview.records) {
      final target = firestore.doc('users/$uid/${record['path']}');
      final created = await firestore.runTransaction((transaction) async {
        final previous = await transaction.get(target);
        if (previous.exists) return false;
        transaction.set(
          target,
          Map<String, dynamic>.from(record['data'] as Map),
        );
        return true;
      });
      if (created) imported++;
    }
    return imported;
  }

  static String csv(List<Map<String, dynamic>> records, List<String> columns) {
    String cell(Object? value) {
      var text = value is Timestamp
          ? value.toDate().toIso8601String()
          : value?.toString() ?? '';
      if (value is String && RegExp(r'^[=+\-@]').hasMatch(text)) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    return '\uFEFF${columns.map(cell).join(',')}\r\n${records.map((record) => columns.map((key) => cell(record[key])).join(',')).join('\r\n')}';
  }
}
