import '../../productivity/services/trash_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/para_area_model.dart';
import '../models/para_project_model.dart';
import '../models/para_resource_model.dart';

/// Comprehensive Firestore service for managing the PARA organizational framework
/// (Projects, Areas, Resources, Archive) with 100% per-user data isolation.
class ParaService {
  static final ParaService _instance = ParaService._internal();
  factory ParaService() => _instance;
  ParaService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String,dynamic>> _areasRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('paraAreas');

  CollectionReference<Map<String,dynamic>> _projectsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('paraProjects');

  CollectionReference<Map<String,dynamic>> _resourcesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('paraResources');

  // ===========================================================================
  // 1. PARA AREAS CRUD
  // ===========================================================================

  /// Adds a new Area of Responsibility
  Future<String?> addArea({required String title, String emoji = '🎯'}) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final docRef = _areasRef(uid).doc();
    final area = ParaAreaModel(
      id: docRef.id,
      title: title.trim(),
      emoji: emoji.trim().isEmpty ? '🎯' : emoji.trim(),
      createdAt: DateTime.now(),
    );

    await docRef.set(area.toMap());
    return docRef.id;
  }

  /// Updates an existing Area
  Future<void> updateArea({
    required String areaId,
    required String title,
    required String emoji,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _areasRef(uid).doc(areaId).update({
      'title': title.trim(),
      'emoji': emoji.trim().isEmpty ? '🎯' : emoji.trim(),
    });
  }

  /// Deletes an Area. Returns false if active projects still belong to it.
  Future<bool> deleteArea(String areaId) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    // Check if any active projects are linked to this area
    final activeProjectsSnap = await _projectsRef(uid)
        .where('areaId', isEqualTo: areaId)
        .where('archived', isEqualTo: false)
        .get();

    if (activeProjectsSnap.docs.isNotEmpty) {
      return false; // Blocked: Still has active projects
    }

    final area = _areasRef(uid).doc(areaId);
    await area.update({'deletionPending': true});
    for (final name in ['paraProjects', 'paraResources', 'goals']) {
      while (true) {
        final linked = await _firestore
            .collection('users')
            .doc(uid)
            .collection(name)
            .where('areaId', isEqualTo: areaId)
            .limit(150)
            .get();
        if (linked.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in linked.docs) {
          batch.update(doc.reference, {'areaId': null});
        }
        await batch.commit();
      }
    }
    await area.delete();
    return true;
  }

  // ===========================================================================
  // 2. PARA PROJECTS CRUD
  // ===========================================================================

  /// Adds a new PARA Project
  Future<String?> addProject({
    required String title,
    required String areaId,
    DateTime? deadline,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final docRef = _projectsRef(uid).doc();
    final project = ParaProjectModel(
      id: docRef.id,
      title: title.trim(),
      areaId: areaId,
      deadline: deadline,
      archived: false,
      createdAt: DateTime.now(),
    );

    await _firestore.runTransaction((tx) async {
      final area = await tx.get(_areasRef(uid).doc(areaId));
      if (!area.exists || area.data()?['deletionPending'] == true) {
        throw StateError('Area unavailable');
      }
      tx.set(docRef, project.toMap());
    });
    return docRef.id;
  }

  /// Updates a PARA Project
  Future<void> updateProject({
    required String projectId,
    required String title,
    required String areaId,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final Map<String, dynamic> updates = {
      'title': title.trim(),
      'areaId': areaId,
    };

    if (clearDeadline) {
      updates['deadline'] = null;
    } else if (deadline != null) {
      updates['deadline'] = Timestamp.fromDate(deadline);
    }

    await _firestore.runTransaction((tx) async {
      final area = await tx.get(_areasRef(uid).doc(areaId));
      final target = _projectsRef(uid).doc(projectId),
          project = await tx.get(target);
      if (!area.exists ||
          area.data()?['deletionPending'] == true ||
          !project.exists ||
          project.data()?['deletionPending'] == true) {
        throw StateError('Project or area unavailable');
      }
      tx.update(target, updates);
    });
  }

  /// Soft-archives or un-archives a Project
  Future<void> setProjectArchived(
    String projectId, {
    required bool archived,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _projectsRef(uid).doc(projectId).update({'archived': archived});
  }

  /// Permanently deletes a Project and unlinks it from all associated tasks
  Future<void> deleteProject(String projectId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final project = _projectsRef(uid).doc(projectId);
    await project.update({'deletionPending': true});
    for (final collection in ['tasks', 'retrospectives', 'goals']) {
      while (true) {
        final linked = await _firestore
            .collection('users')
            .doc(uid)
            .collection(collection)
            .where('projectId', isEqualTo: projectId)
            .limit(100)
            .get();
        if (linked.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in linked.docs) {
          batch.update(doc.reference, {'projectId': null});
        }
        await batch.commit();
      }
    }
    await project.delete();
  }

  // ===========================================================================
  // 3. PARA RESOURCES CRUD
  // ===========================================================================

  /// Adds a new Knowledge Resource
  Future<String?> addResource({
    required String title,
    String? notes,
    List<String> tags = const [],
  }) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final docRef = _resourcesRef(uid).doc();
    final resource = ParaResourceModel(
      id: docRef.id,
      title: title.trim(),
      notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      tags: tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      archived: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(resource.toMap());
    return docRef.id;
  }

  /// Updates an existing Resource
  Future<void> updateResource({
    required String resourceId,
    required String title,
    String? notes,
    List<String> tags = const [],
    bool clearNotes = false,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final Map<String, dynamic> updates = {
      'title': title.trim(),
      'tags': tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
    };

    if (clearNotes) {
      updates['notes'] = null;
    } else if (notes != null) {
      updates['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    await _resourcesRef(uid).doc(resourceId).update(updates);
  }

  /// Soft-archives or un-archives a Resource
  Future<void> setResourceArchived(
    String resourceId, {
    required bool archived,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _resourcesRef(uid).doc(resourceId).update({'archived': archived});
  }

  /// Permanently deletes a Resource
  Future<void> deleteResource(String resourceId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await TrashService(_firestore).move(uid, 'paraResources', resourceId);
  }
}
