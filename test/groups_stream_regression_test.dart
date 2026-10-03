import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/features/groups/models/group_model.dart';
import 'package:focusly/features/groups/providers/groups_provider.dart';

class GroupTestSession extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void change(String? uid) => state = uid;
}

final groupTestSessionProvider = NotifierProvider<GroupTestSession, String?>(
  GroupTestSession.new,
);

Future<List<GroupModel>> waitForGroups(
  ProviderContainer container,
  bool Function(List<GroupModel>) matches,
) async {
  final result = Completer<List<GroupModel>>();
  final subscription = container.listen(myGroupsStreamProvider, (_, next) {
    if (next.hasValue && matches(next.value!) && !result.isCompleted) {
      result.complete(next.value!);
    }
  }, fireImmediately: true);
  try {
    return await result.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('users/alice').set({
      'groupIds': ['g1'],
    });
    await firestore.doc('users/bob').set({'groupIds': []});
    for (final id in ['g1', 'g2']) {
      await firestore.doc('groups/$id').set({
        'name': id,
        'createdBy': 'alice',
        'memberCount': 1,
      });
    }
    container = ProviderContainer(
      overrides: [
        groupsFirestoreProvider.overrideWithValue(firestore),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(groupTestSessionProvider),
        ),
      ],
    );
    container.listen(myGroupsStreamProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  test(
    'adding and removing memberships updates the active group query',
    () async {
      await waitForGroups(container, (groups) => groups.length == 1);
      await firestore.doc('users/alice').update({
        'groupIds': ['g1', 'g2'],
      });
      final joined = await waitForGroups(
        container,
        (groups) => groups.length == 2,
      );
      expect(joined.map((group) => group.id), containsAll(['g1', 'g2']));
      await firestore.doc('users/alice').update({
        'groupIds': ['g2'],
      });
      await waitForGroups(
        container,
        (groups) => groups.length == 1 && groups.single.id == 'g2',
      );
    },
  );

  test('group metadata stays live after membership changes', () async {
    await waitForGroups(container, (groups) => groups.length == 1);
    await firestore.doc('groups/g1').update({'name': 'Renamed'});
    await waitForGroups(
      container,
      (groups) => groups.length == 1 && groups.single.name == 'Renamed',
    );
  });

  test('switching accounts clears the previous account groups', () async {
    await waitForGroups(container, (groups) => groups.length == 1);
    container.read(groupTestSessionProvider.notifier).change('bob');
    await waitForGroups(container, (groups) => groups.isEmpty);
    await firestore.doc('users/alice').update({
      'groupIds': ['g2'],
    });
    await container.pump();
    expect(container.read(myGroupsStreamProvider).value, isEmpty);
  });
}
