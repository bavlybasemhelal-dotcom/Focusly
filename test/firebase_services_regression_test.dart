import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/account_deletion/account_deletion_service.dart';
import 'package:focusly/core/auth/user_profile_service.dart';
import 'package:focusly/features/groups/services/group_service.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

// Firebase User is mutable; the test records deletion without changing production models.
// ignore: must_be_immutable
class TrackingUser extends MockUser {
  bool deleted = false;
  TrackingUser(DateTime signIn)
    : super(
        uid: 'alice',
        metadata: UserMetadata(
          signIn.millisecondsSinceEpoch,
          signIn.millisecondsSinceEpoch,
        ),
      );
  @override
  Future<void> delete() async {
    deleted = true;
  }
}

class SwitchableAuth extends MockFirebaseAuth {
  User? session;
  @override
  User? get currentUser => session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late FakeFirebaseFirestore firestore;
  late GroupService groups;
  setUp(() async {
    firestore = FakeFirebaseFirestore();
    groups = GroupService(firestore: firestore, actorProvider: () => 'admin');
    await firestore.doc('users/alice').set({'groupIds': []});
    await firestore.doc('groups/g1').set({
      'createdBy': 'admin',
      'memberCount': 1,
      'maxMembers': 2,
    });
    await firestore.doc('groups/g1/members/admin').set({
      'uid': 'admin',
      'role': 'admin',
      'status': 'approved',
    });
    await firestore.doc('groups/g1/members/alice').set({
      'uid': 'alice',
      'role': 'member',
      'status': 'pending',
    });
  });
  test('approving a request twice counts the member only once', () async {
    await groups.approveMember('g1', 'alice');
    await groups.approveMember('g1', 'alice');
    expect((await firestore.doc('groups/g1').get()).data()?['memberCount'], 2);
    expect((await firestore.doc('users/alice').get()).data()?['groupIds'], [
      'g1',
    ]);
  });
  test('Google profile provisioning preserves an existing profile', () async {
    final profile = firestore.doc('users/alice');
    await profile.set({
      'name': 'Original name',
      'groupIds': ['g1'],
    });
    final created = await UserProfileService(firestore: firestore)
        .ensureUserProfileDocument(
          user: MockUser(uid: 'alice', displayName: 'Google name'),
        );
    expect(created, isFalse);
    expect((await profile.get()).data(), {
      'name': 'Original name',
      'groupIds': ['g1'],
    });
  });
  test('failed profile reads never trigger a replacement write', () async {
    final before = firestore.dump();
    whenCalling(Invocation.method(#get, null))
        .on(firestore.doc('users/alice'))
        .thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
    await expectLater(
      UserProfileService(
        firestore: firestore,
      ).ensureUserProfileDocument(user: MockUser(uid: 'alice')),
      throwsA(isA<FirebaseException>()),
    );
    expect(firestore.dump(), before);
  });
  test('Google profile provisioning creates a missing profile', () async {
    final created = await UserProfileService(firestore: firestore)
        .ensureUserProfileDocument(
          user: MockUser(uid: 'new-user', displayName: ' New user '),
        );
    expect(created, isTrue);
    final profile = (await firestore.doc('users/new-user').get()).data();
    expect(profile?['uid'], 'new-user');
    expect(profile?['name'], 'New user');
    expect(profile?['createdAt'], isA<Timestamp>());
  });
  test('approval refuses a full group without changing the request', () async {
    await firestore.doc('groups/g1').update({'memberCount': 2});
    await expectLater(groups.approveMember('g1', 'alice'), throwsStateError);
    expect(
      (await firestore.doc('groups/g1/members/alice').get()).data()?['status'],
      'pending',
    );
    expect(
      (await firestore.doc('users/alice').get()).data()?['groupIds'],
      isEmpty,
    );
  });
  test('leaving a group twice does not decrement the count twice', () async {
    await groups.approveMember('g1', 'alice');
    await groups.leaveGroup('g1', 'alice');
    await groups.leaveGroup('g1', 'alice');
    expect((await firestore.doc('groups/g1').get()).data()?['memberCount'], 1);
    expect(
      (await firestore.doc('users/alice').get()).data()?['groupIds'],
      isEmpty,
    );
  });
  test(
    'cancelling a pending request does not decrement approved members',
    () async {
      await groups.leaveGroup('g1', 'alice');
      expect(
        (await firestore.doc('groups/g1').get()).data()?['memberCount'],
        1,
      );
    },
  );
  test(
    'group cascade clears large feeds and nested completion records',
    () async {
      for (var i = 0; i < 850; i++) {
        await firestore.doc('groups/g1/feed/$i').set({'uid': 'admin'});
      }
      await firestore.doc('groups/g1/assignments/a1').set({
        'title': 'Assignment',
      });
      await firestore.doc('groups/g1/assignments/a1/completions/alice').set({
        'status': 'done',
      });
      await groups.deleteGroup('g1');
      expect((await firestore.doc('groups/g1').get()).exists, isFalse);
      expect(
        (await firestore.collection('groups/g1/feed').get()).docs,
        isEmpty,
      );
      expect(
        (await firestore.collectionGroup('completions').get()).docs,
        isEmpty,
      );
      expect((await firestore.doc('users/alice').get()).data(), {
        'groupIds': [],
      });
    },
  );
  test(
    'stale authentication requests verification before deleting any data',
    () async {
      final user = TrackingUser(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      await firestore.doc('users/alice/tasks/private').set({
        'title': 'Keep this',
      });
      final deletion = AccountDeletionService(
        auth: auth,
        firestore: firestore,
        groupService: groups,
      );
      await expectLater(
        deletion.deleteCurrentAccount(),
        throwsA(isA<ReauthenticationRequiredException>()),
      );
      expect(
        (await firestore.doc('users/alice/tasks/private').get()).exists,
        isTrue,
      );
      expect(user.deleted, isFalse);
    },
  );
  test(
    'reauthentication cannot redirect deletion to a different account',
    () async {
      final auth = SwitchableAuth()
        ..session = TrackingUser(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      final deletion = AccountDeletionService(
        auth: auth,
        firestore: firestore,
        groupService: groups,
      );
      await expectLater(
        deletion.deleteCurrentAccount(),
        throwsA(isA<ReauthenticationRequiredException>()),
      );
      auth.session = MockUser(
        uid: 'bob',
        metadata: UserMetadata(
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await expectLater(
        deletion.finalizeAuthDeletionAfterReauth(),
        throwsStateError,
      );
      expect((await firestore.doc('users/alice').get()).exists, isTrue);
    },
  );
  test(
    'failed personal cleanup leaves the profile and auth account available for retry',
    () async {
      final user = TrackingUser(DateTime.now());
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      final task = firestore.doc('users/alice/tasks/private');
      await task.set({'title': 'Keep this'});
      whenCalling(Invocation.method(#delete, null))
          .on(task)
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
      final deletion = AccountDeletionService(
        auth: auth,
        firestore: firestore,
        groupService: groups,
      );
      await expectLater(
        deletion.deleteCurrentAccount(),
        throwsA(isA<FirebaseException>()),
      );
      expect((await firestore.doc('users/alice').get()).exists, isTrue);
      expect((await task.get()).exists, isTrue);
      expect(user.deleted, isFalse);
    },
  );
  test(
    'verified deletion removes data and pending membership before deleting auth',
    () async {
      final user = TrackingUser(DateTime.now());
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      for (var i = 0; i < 810; i++) {
        await firestore.doc('users/alice/tasks/$i').set({'title': 'Task'});
      }
      await AccountDeletionService(
        auth: auth,
        firestore: firestore,
        groupService: groups,
      ).finalizeAuthDeletionAfterReauth();
      expect(
        (await firestore.collection('users/alice/tasks').get()).docs,
        isEmpty,
      );
      expect(
        (await firestore.doc('groups/g1/members/alice').get()).exists,
        isFalse,
      );
      expect((await firestore.doc('users/alice').get()).exists, isFalse);
      expect(user.deleted, isTrue);
    },
  );
}
