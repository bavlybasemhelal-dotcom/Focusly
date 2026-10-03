import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, collectionGroup, query, where, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, arrayUnion, arrayRemove, setLogLevel, Timestamp, serverTimestamp } from 'firebase/firestore';
setLogLevel('silent');

let env;
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const member = (uid, status = 'approved', role = 'member') => ({ uid, name: uid, status, role, weeklyXP: 0, inviteCode:'GRP-TEST' });
const group = { createdBy: 'admin', memberCount: 2, maxMembers: 20, name: 'Test', inviteCode: 'GRP-TEST' };
const assignment = { createdBy: 'admin', type: 'task', title: 'Assigned task', assignedTo: ['alice'], deadline: null, completionMode: 'simple', targetCount: null };
const taskData = { title: 'Assigned task', groupAssignmentId: 'a1', assignedByGroupId: 'g1', locked: true, deadline: null, completionMode: 'simple', targetCount: null, done: false, currentCount:0, date:Timestamp.now(), createdAt:Timestamp.now() };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-focusly',
    firestore: { host: '127.0.0.1', port: 8080, rules: readFileSync(process.env.FOCUSLY_RULES_PATH || new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const seed = context.firestore();
    const batch = writeBatch(seed);
    batch.set(doc(seed, 'groups/g1'), group);
    batch.set(doc(seed, 'groups/g1/members/admin'), member('admin', 'approved', 'admin'));
    batch.set(doc(seed, 'groups/g1/members/alice'), member('alice'));
    batch.set(doc(seed, 'groups/g1/members/bob'), member('bob', 'pending'));
    batch.set(doc(seed, 'users/alice'), { name: 'Private name', email: 'private@example.com', groupIds: ['g1'] });
    batch.set(doc(seed, 'users/bob'), { name: 'Bob', groupIds: [] });
    batch.set(doc(seed, 'groups/g1/assignments/a1'), assignment);
    batch.set(doc(seed, 'users/alice/tasks/locked'), taskData);
    batch.set(doc(seed,'groups/g1/assignments/a1/completions/alice'),{uid:'alice',itemId:'locked',status:'pending',currentCount:0,completedAt:null});
    batch.set(doc(seed,'invites/GRP-TEST'),{groupId:'g1',name:'Test',icon:'🧩',maxMembers:20,memberCount:2});
    await batch.commit();
  });
});

test('all registered personal collections are writable only by their owner', async () => {
  const registry = readFileSync(new URL('../../lib/core/account_deletion/user_data_collections.dart', import.meta.url), 'utf8');
  const body=registry.slice(registry.indexOf('const List<String>'));
  const names=[...body.matchAll(/'([^']+)'/g)].map(match=>match[1]);
  for (const name of names) {
    const ref=doc(db('alice'),`users/alice/${name}/test`);
    const data=name==='tasks'?{done:false,date:Timestamp.now()}:name==='habits'?{days:Array(7).fill(false)}:{value:name};
    if(['completionEvents','xpLog'].includes(name)) {
      await assertFails(setDoc(ref,data));
      await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),`users/alice/${name}/test`),data));
      await assertFails(deleteDoc(ref));
    }else{await assertSucceeds(setDoc(ref,data));await assertSucceeds(deleteDoc(ref));}
    await assertFails(getDoc(doc(db('bob'),`users/alice/${name}/test`)));
    await assertFails(setDoc(doc(db('bob'),`users/alice/${name}/test`),{value:'stolen'}));
  }
});
test('anonymous access is denied', async () => {
  await assertFails(getDoc(doc(db(), 'users/alice')));
  await assertFails(getDoc(doc(db(), 'groups/g1')));
});
test('pending applicants cannot approve themselves or become admins', async () => {
  await assertFails(updateDoc(doc(db('bob'), 'groups/g1/members/bob'), { status: 'approved', role: 'admin' }));
});
test('approved members cannot promote themselves', async () => {
  await assertFails(updateDoc(doc(db('alice'), 'groups/g1/members/alice'), { role: 'admin' }));
});
test('join requests must start pending with the member role and correct uid', async () => {
  await assertFails(setDoc(doc(db('eve'), 'groups/g1/members/eve'), member('eve', 'approved', 'admin')));
  await assertFails(setDoc(doc(db('eve'), 'groups/g1/members/eve'), member('alice', 'pending')));
  await assertSucceeds(setDoc(doc(db('eve'), 'groups/g1/members/eve'), member('eve', 'pending')));
});
test('a creator can atomically bootstrap their own group and admin membership', async () => {
  const store = db('creator');
  const batch = writeBatch(store);
  batch.set(doc(store, 'groups/new'), { ...group, createdBy: 'creator', memberCount: 1 });
  batch.set(doc(store, 'groups/new/members/creator'), member('creator', 'approved', 'admin'));
  batch.set(doc(store, 'users/creator'), { groupIds: ['new'] });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db('eve'), 'groups/spoof'), { ...group, createdBy: 'admin' }));
});
test('admins approve members and update only their groupIds atomically', async () => {
  const store = db('admin');
  const batch = writeBatch(store);
  batch.update(doc(store, 'groups/g1/members/bob'), { status: 'approved' });
  batch.update(doc(store, 'groups/g1'), { memberCount: 3,lastMembershipUid:'bob' });
  batch.update(doc(store, 'users/bob'), { groupIds: arrayUnion('g1') });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(store, 'users/bob'), { name: 'Tampered' }));
  await assertFails(getDoc(doc(store, 'users/alice')));
});
test('members leave atomically and cannot arbitrarily edit group counts', async () => {
  const store = db('alice');
  await assertFails(updateDoc(doc(store, 'groups/g1'), { memberCount: 0 }));
  const batch = writeBatch(store);
  batch.delete(doc(store, 'groups/g1/members/alice'));
  batch.update(doc(store, 'groups/g1'), { memberCount: 1,lastMembershipUid:'alice' });
  batch.update(doc(store, 'users/alice'), { groupIds: arrayRemove('g1') });
  await assertSucceeds(batch.commit());
});
test('group cleanup can retry a membership removal without editing other profile fields', async () => {
  const store = db('admin');
  await assertSucceeds(updateDoc(doc(store, 'users/alice'), { groupIds: arrayRemove('g1') }));
  await assertSucceeds(updateDoc(doc(store, 'users/alice'), { groupIds: arrayRemove('g1') }));
  await assertFails(updateDoc(doc(store, 'users/alice'), { name: 'Tampered' }));
});
test('member collection group queries expose only the caller memberships', async () => {
  await assertSucceeds(getDocs(query(collectionGroup(db('bob'), 'members'), where('uid', '==', 'bob'))));
  await assertFails(getDocs(query(collectionGroup(db('eve'), 'members'), where('uid', '==', 'alice'))));
  await assertFails(getDocs(collection(db('eve'), 'groups/g1/members')));
});
test('admins distribute assignments without access to existing personal tasks', async () => {
  const store = db('admin');
  const batch = writeBatch(store);
  batch.set(doc(store, 'groups/g1/assignments/a2'), assignment);
  batch.set(doc(store, 'groups/g1/assignments/a2/completions/alice'), {uid:'alice',itemId:'a2',status:'pending',currentCount:0,completedAt:null});
  batch.set(doc(store, 'users/alice/tasks/a2'), { ...taskData, groupAssignmentId: 'a2' });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(store, 'users/alice/tasks/locked'), { title: 'Tampered' }));
  await assertFails(setDoc(doc(store, 'users/bob/tasks/a2'), { ...taskData, groupAssignmentId: 'a2' }));
});
test('assignment distribution supports a full group of twenty members', async () => {
  const uids = ['admin', 'alice', ...Array.from({ length: 18 }, (_, i) => `member-${i}`)];
  await env.withSecurityRulesDisabled(async context => {
    const seed = context.firestore();
    const batch = writeBatch(seed);
    for (const uid of uids) {
      batch.set(doc(seed, `groups/g1/members/${uid}`), member(uid, 'approved', uid === 'admin' ? 'admin' : 'member'));
    }
    await batch.commit();
  });
  const store = db('admin');
  await assertSucceeds(setDoc(doc(store,'groups/g1/assignments/full'),{...assignment,assignedTo:uids}));
  for(const uid of uids){
    const batch=writeBatch(store);
    batch.set(doc(store,`groups/g1/assignments/full/completions/${uid}`),{uid,itemId:'full',status:'pending',currentCount:0,completedAt:null});
    batch.set(doc(store,`users/${uid}/tasks/full`),{...taskData,groupAssignmentId:'full'});
    await assertSucceeds(batch.commit());
  }
});
test('members complete locked assignments without changing the assigned title', async () => {
  const store = db('alice');
  await assertFails(updateDoc(doc(store,'users/alice/tasks/locked'),{done:true}));
  const pair=writeBatch(store);pair.update(doc(store,'users/alice/tasks/locked'),{done:true,doneAt:serverTimestamp()});pair.update(doc(store,'groups/g1/assignments/a1/completions/alice'),{status:'done',currentCount:1,completedAt:serverTimestamp()});await assertSucceeds(pair.commit());
  await assertFails(updateDoc(doc(store, 'users/alice/tasks/locked'), { title: 'Tampered', locked: false }));
  await assertFails(setDoc(doc(store, 'groups/g1/assignments/a1/completions/alice'), { status: 'done', currentCount: 1 }));
  await assertFails(setDoc(doc(db('bob'), 'groups/g1/assignments/a1/completions/bob'), { status: 'done' }));
});
test('members cannot forge feed authors or edit message content', async () => {
  const store = db('alice');
  await assertFails(setDoc(doc(store, 'groups/g1/feed/forged'), { uid: 'admin', message: 'Forged' }));
  await assertSucceeds(setDoc(doc(store, 'groups/g1/feed/real'), { uid: 'alice', message: 'Hello', reactions: {}, reactedBy: {} }));
  await assertFails(updateDoc(doc(store, 'groups/g1/feed/real'), { message: 'Changed' }));
  await assertSucceeds(updateDoc(doc(store, 'groups/g1/feed/real'), { reactions: { like: 1 }, reactedBy: { alice: 'like' } }));
});
test('creator retains deletion permission after removing their member record', async () => {
  const store = db('admin');
  const leave=writeBatch(store);leave.delete(doc(store,'groups/g1/members/admin'));leave.update(doc(store,'groups/g1'),{memberCount:1,lastMembershipUid:'admin'});await assertSucceeds(leave.commit());
  await assertSucceeds(deleteDoc(doc(store, 'groups/g1/assignments/a1')));
  await assertSucceeds(deleteDoc(doc(store, 'groups/g1')));
});
test('a member joins a challenge atomically without permission to edit its goal', async () => {
  const admin = db('admin');
  const creation = writeBatch(admin);
  creation.set(doc(admin, 'groups/g1/challenges/c1'), {
    createdBy: 'admin', type:'tasks',status:'active',goal:10,participantCount:1,startDate:Timestamp.now(),
    endDate: Timestamp.fromDate(new Date(Date.now() + 86400000)),
  });
  creation.set(doc(admin,'groups/g1/challenges/c1/participants/admin'),{uid:'admin',score:0,baseline:0,joinedAt:Timestamp.now()});
  await assertSucceeds(creation.commit());
  const store = db('alice');
  const batch = writeBatch(store);
  batch.set(doc(store, 'groups/g1/challenges/c1/participants/alice'), {uid:'alice',score:0,baseline:0,joinedAt:Timestamp.now()});
  batch.update(doc(store, 'groups/g1/challenges/c1'), { participantCount: 2 });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(store, 'groups/g1/challenges/c1'), { goal: 0 }));
  await assertFails(updateDoc(doc(store, 'groups/g1/challenges/c1'), { participantCount: 3 }));
  await assertFails(updateDoc(doc(store, 'groups/g1/challenges/c1'), { status: 'finished', winnerUid: 'alice' }));
});
