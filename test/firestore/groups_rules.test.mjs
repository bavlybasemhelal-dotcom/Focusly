import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, getDoc, getDocs, collection, deleteDoc, writeBatch, serverTimestamp, Timestamp, setLogLevel} from 'firebase/firestore';
setLogLevel('silent');
let env;
before(async () => {env = await initializeTestEnvironment({projectId:'demo-focusly-group-contracts',
  firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    for (const uid of ['owner','alice','admin','outsider']) await setDoc(doc(db,`users/${uid}`),{groupIds:uid === 'outsider'?[]:['g']});
    await setDoc(doc(db,'groups/g'),{createdBy:'owner',memberCount:3,maxMembers:20,inviteCode:'GRP-SECRET'});
    for (const [uid,role] of [['owner','admin'],['admin','admin'],['alice','member']]) {
      await setDoc(doc(db,`groups/g/members/${uid}`),{uid,role,status:'approved',weeklyXP:0});
    }
    await setDoc(doc(db,'invites/GRP-SECRET'),{groupId:'g',name:'Group',icon:'g',memberCount:3,maxMembers:20});
    await setDoc(doc(db,'groups/g/assignments/a'),{type:'task',title:'Task',createdBy:'owner',assignedTo:['alice'],completionMode:'count',targetCount:5,deadline:null});
    await setDoc(doc(db,'users/alice/tasks/t'),{title:'Task',date:Timestamp.now(),done:false,doneAt:null,currentCount:0,targetCount:5,completionMode:'count',locked:true,assignedByGroupId:'g',groupAssignmentId:'a',deadline:null});
    await setDoc(doc(db,'groups/g/assignments/a/completions/alice'),{uid:'alice',itemId:'t',status:'pending',currentCount:0,completedAt:null,decision:'offered'});
    await setDoc(doc(db,'groups/g/challenges/c'),{createdBy:'owner',type:'tasks',status:'active',goal:5,participantCount:1,startDate:Timestamp.fromMillis(Date.now()-60000),endDate:Timestamp.fromMillis(Date.now()+60000)});
    await setDoc(doc(db,'groups/g/challenges/c/participants/alice'),{uid:'alice',score:0,baseline:0,joinedAt:Timestamp.fromMillis(Date.now()-30000)});
  });
});
const db = uid => env.authenticatedContext(uid).firestore();
test('moderators approve a pending member with a truthful atomic audit and cannot forge role changes', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(),'groups/g/members/mod'),{uid:'mod',role:'moderator',status:'approved',weeklyXP:0});
    await updateDoc(doc(ctx.firestore(),'groups/g'),{memberCount:4});
    await setDoc(doc(ctx.firestore(),'groups/g/members/outsider'),{uid:'outsider',role:'member',status:'pending',weeklyXP:0});
  });
  const store=db('mod'),batch=writeBatch(store);
  batch.update(doc(store,'groups/g/members/outsider'),{status:'approved',joinedAt:serverTimestamp()});
  batch.update(doc(store,'groups/g'),{memberCount:5,lastMembershipUid:'outsider'});
  batch.update(doc(store,'users/outsider'),{groupIds:['g']});
  batch.set(doc(store,'groups/g/audit/approved'),{actorUid:'mod',action:'approveMember',target:'outsider',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(store,'groups/g/members/alice'),{role:'admin'}));
  await assertFails(setDoc(doc(store,'groups/g/audit/forged'),{actorUid:'mod',action:'approveMember',target:'alice',createdAt:serverTimestamp()}));
});
test('ownership transfer requires the current owner and an approved new admin', async () => {
  const store=db('owner'),batch=writeBatch(store);
  batch.update(doc(store,'groups/g/members/alice'),{role:'admin'});
  batch.update(doc(store,'groups/g'),{createdBy:'alice',ownershipChangedAt:serverTimestamp()});
  batch.set(doc(store,'groups/g/audit/transfer'),{actorUid:'owner',action:'transferOwnership',target:'alice',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(deleteDoc(doc(db('owner'),'groups/g')));
  await assertSucceeds(deleteDoc(doc(db('alice'),'groups/g')));
});
test('distributed assignment definitions are immutable and numeric bounds are enforced', async () => {
  await assertFails(updateDoc(doc(db('owner'),'groups/g/assignments/a'),{title:'Changed after dispatch'}));
  await assertSucceeds(updateDoc(doc(db('owner'),'groups/g/assignments/a'),{distributionPending:false}));
  await assertFails(setDoc(doc(db('owner'),'groups/g/assignments/invalid'),{type:'task',title:'Count',createdBy:'owner',assignedTo:['alice'],completionMode:'count',targetCount:0,deadline:null}));
});
test('body readings require a complete pressure pair and reject non-finite numbers', async () => {
  const target=doc(db('alice'),'users/alice/bodyMetrics/read');
  await assertFails(setDoc(target,{bpSystolic:120}));
  await assertFails(setDoc(target,{weight:NaN}));
  await assertSucceeds(setDoc(target,{bpSystolic:120,bpDiastolic:80,pulse:70}));
});
test('outsiders cannot enumerate groups or invitations or read full metadata', async () => {
  await assertFails(getDocs(collection(db('outsider'),'groups')));
  await assertFails(getDocs(collection(db('outsider'),'invites')));
  await assertFails(getDoc(doc(db('outsider'),'groups/g')));
  await assertSucceeds(getDoc(doc(db('outsider'),'invites/GRP-SECRET')));
});
test('pending membership requires the exact invitation and never admin self-promotion', async () => {
  await assertFails(setDoc(doc(db('outsider'),'groups/g/members/outsider'),{uid:'outsider',role:'member',status:'pending',inviteCode:'WRONG'}));
  await assertFails(setDoc(doc(db('outsider'),'groups/g/members/outsider'),{uid:'outsider',role:'admin',status:'approved'}));
  await assertSucceeds(setDoc(doc(db('outsider'),'groups/g/members/outsider'),{uid:'outsider',role:'member',status:'pending',inviteCode:'GRP-SECRET'}));
});
test('an added admin cannot destroy the owner group', async () => {
  await assertFails(deleteDoc(doc(db('admin'),'groups/g')));
});
test('a locked assignment cannot be deleted, unlocked or renamed by its recipient', async () => {
  await assertFails(deleteDoc(doc(db('alice'),'users/alice/tasks/t')));
  await assertFails(updateDoc(doc(db('alice'),'users/alice/tasks/t'),{locked:false}));
  await assertFails(updateDoc(doc(db('alice'),'users/alice/tasks/t'),{title:'Forged'}));
});
test('partial progress requires an atomic matching personal/group pair', async () => {
  await assertFails(updateDoc(doc(db('alice'),'users/alice/tasks/t'),{currentCount:2}));
  const store=db('alice');const batch=writeBatch(store);
  batch.update(doc(store,'users/alice/tasks/t'),{currentCount:2,done:false,doneAt:null});
  batch.update(doc(store,'groups/g/assignments/a/completions/alice'),{currentCount:2});
  await assertSucceeds(batch.commit());
});
test('forged identity, negative counts, fake done status and unknown completion keys fail', async () => {
  const ref=doc(db('alice'),'groups/g/assignments/a/completions/alice');
  for (const changes of [{uid:'owner'},{currentCount:-1},{status:'done',completedAt:serverTimestamp()},{admin:true},{currentCount:9999}]) {
    await assertFails(updateDoc(ref,changes));
  }
});
test('challenge scores cannot be typed directly and participants cannot be forged', async () => {
  await assertFails(updateDoc(doc(db('alice'),'groups/g/challenges/c/participants/alice'),{score:999}));
  await assertFails(setDoc(doc(db('alice'),'groups/g/challenges/c/participants/owner'),{uid:'owner',score:100,baseline:0,joinedAt:Timestamp.now()}));
  await assertFails(updateDoc(doc(db('alice'),'groups/g/challenges/c'),{winnerUid:'alice',status:'finished'}));
});
test('deleting a participant updates its parent count atomically', async () => {
  await assertFails(deleteDoc(doc(db('alice'),'groups/g/challenges/c/participants/alice')));
  const store=db('alice');const batch=writeBatch(store);
  batch.delete(doc(store,'groups/g/challenges/c/participants/alice'));
  batch.update(doc(store,'groups/g/challenges/c'),{participantCount:0,lastRemovedParticipant:'alice'});
  await assertSucceeds(batch.commit());
});
test('membership counters cannot be changed without a real membership transition', async () => {
  await assertFails(updateDoc(doc(db('owner'),'groups/g'),{memberCount:99,lastMembershipUid:'alice'}));
  await assertFails(updateDoc(doc(db('alice'),'groups/g'),{memberCount:2,lastMembershipUid:'alice'}));
});
test('new feed posts cannot forge reactions', async () => {
  await assertFails(setDoc(doc(db('alice'),'groups/g/feed/f'),{uid:'alice',reactedBy:{owner:'like'},reactions:{like:1}}));
  await assertSucceeds(setDoc(doc(db('alice'),'groups/g/feed/f'),{uid:'alice',reactedBy:{},reactions:{like:0,fire:0,clap:0}}));
});
