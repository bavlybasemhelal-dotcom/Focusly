import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupManagementService {
  GroupManagementService(this.firestore);
  final FirebaseFirestore firestore;
  void audit(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> group,
    String actor,
    String action,
    String target,
  ) {
    tx.set(group.collection('audit').doc(), {
      'actorUid': actor,
      'action': action,
      'target': target,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRole(
    String groupId,
    String actor,
    String memberUid,
    String role,
  ) async {
    if (!['member', 'admin', 'moderator'].contains(role)) {
      throw ArgumentError('Invalid role');
    }
    final group = firestore.collection('groups').doc(groupId);
    await firestore.runTransaction((tx) async {
      final root = await tx.get(group),
          member = await tx.get(group.collection('members').doc(memberUid));
      if (root.data()?['createdBy'] != actor ||
          memberUid == actor ||
          member.data()?['status'] != 'approved') {
        throw StateError('Only the owner can change an approved member role');
      }
      tx.update(member.reference, {'role': role});
      audit(tx, group, actor, 'setRole:$role', memberUid);
    });
  }

  Future<void> transfer(String groupId, String actor, String nextOwner) async {
    final group = firestore.collection('groups').doc(groupId);
    await firestore.runTransaction((tx) async {
      final root = await tx.get(group),
          member = await tx.get(group.collection('members').doc(nextOwner));
      if (root.data()?['createdBy'] != actor ||
          actor == nextOwner ||
          member.data()?['status'] != 'approved') {
        throw StateError('Choose another approved member');
      }
      tx.update(member.reference, {'role': 'admin'});
      tx.update(group, {
        'createdBy': nextOwner,
        'ownershipChangedAt': FieldValue.serverTimestamp(),
      });
      audit(tx, group, actor, 'transferOwnership', nextOwner);
    });
  }

  Future<String> rotateInvite(String groupId, String actor) async {
    final random = Random.secure();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code =
        'GRP${List.generate(12, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
    final group = firestore.collection('groups').doc(groupId);
    await firestore.runTransaction((tx) async {
      final root = await tx.get(group);
      if (root.data()?['createdBy'] != actor) {
        throw StateError('Only the owner can rotate invitations');
      }
      final data = root.data()!;
      final old = data['inviteCode'] as String?;
      final target = firestore.collection('invites').doc(code);
      final collision = await tx.get(target);
      if (collision.exists) throw StateError('Invitation collision. Retry.');
      tx.set(target, {
        for (final key in ['name', 'icon', 'maxMembers', 'memberCount'])
          key: data[key],
        'groupId': groupId,
      });
      tx.update(group, {'inviteCode': code});
      if (old != null) tx.delete(firestore.collection('invites').doc(old));
      audit(tx, group, actor, 'rotateInvite', '');
    });
    return code;
  }
}
