import { createHash } from 'node:crypto';
const taskEventKey = createHash('sha256').update('task_t').digest('hex');
import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, setLogLevel, Timestamp } from 'firebase/firestore';
setLogLevel('silent');
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-focusly-rewards', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const store = context.firestore();
    await setDoc(doc(store, 'users/alice'), {groupIds: ['g']});
    await setDoc(doc(store, 'users/alice/tasks/t'), {done: true, title: 'Task'});
    await setDoc(doc(store, 'groups/g'), {createdBy: 'admin', memberCount: 2});
    await setDoc(doc(store, 'groups/g/members/alice'), {uid: 'alice', role: 'member', status: 'approved', weeklyXP: 0});
  });
});
const alice = () => env.authenticatedContext('alice').firestore();
const event = () => {
  const start = new Date(); start.setUTCHours(0, 0, 0, 0);
  start.setUTCDate(start.getUTCDate() - (start.getUTCDay() + 1) % 7);
  return {uid: 'alice', sourceType: 'task', sourceId: 't', amount: 10, source: 'Task',
    createdAt: serverTimestamp(), occurredOn: new Date().toISOString().slice(0, 10), schemaVersion: 1, sourceNumber: 0, sourceDate: '',
    week: start.toISOString().slice(0, 10), timezoneMinutes: 0, weekStartAt: Timestamp.fromDate(start)};
};
async function award(store, amount = 10) {
  const batch = writeBatch(store);
  const data = {...event(), amount};
  batch.set(doc(store, `users/alice/completionEvents/${taskEventKey}`), data);
  batch.set(doc(store, `users/alice/xpLog/${taskEventKey}`), data);
  batch.set(doc(store, 'users/alice/stats/progress'), {xp: amount, lastEventId: taskEventKey, lastUpdated: serverTimestamp()});
  return batch.commit();
}
test('direct forged personal XP is rejected', async () => {
  await assertFails(setDoc(doc(alice(), 'users/alice/stats/progress'), {xp: 999999}));
});
test('learning-linked tasks can only reserve a zero-point completion', async () => {
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(),'users/alice/tasks/t'),{learningSource:{collection:'books',id:'b',step:1}}));
  await assertFails(award(alice(),10));
  await assertSucceeds(award(alice(),0));
});
test('a personal XP total cannot be deleted to reset its ledger', async () => {
  await assertSucceeds(award(alice()));
  await assertFails(deleteDoc(doc(alice(),'users/alice/stats/progress')));
});
test('direct legacy weekly XP is rejected', async () => {
  await assertFails(updateDoc(doc(alice(), 'groups/g/members/alice'), {weeklyXP: 999999}));
});
test('a real task award commits its immutable event and total atomically', async () => {
  await assertSucceeds(award(alice()));
});
test('the wrong amount and missing completion are rejected', async () => {
  await assertFails(award(alice(), 50));
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'users/alice/tasks/t'), {done: false}));
  await assertFails(award(alice()));
});
test('reusing the same event cannot increment the total twice', async () => {
  await assertSucceeds(award(alice()));
  await assertFails(updateDoc(doc(alice(), 'users/alice/stats/progress'), {xp: 20, lastEventId: taskEventKey}));
});
test('an event cannot be rewritten', async () => {
  await assertSucceeds(award(alice()));
  await assertFails(updateDoc(doc(alice(), `users/alice/completionEvents/${taskEventKey}`), {amount: 999}));
});
test('Pomodoro rewards require saved duration and enforce both full and partial caps', async () => {
  let total=0;
  for(const [id,seconds,partial,amount] of [['p5',300,true,6],['p25',1500,false,30],['partial25',1500,true,29]]){
    await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),`users/alice/pomodoroLogs/${id}`),{durationSeconds:seconds,partial}));
    const store=alice(),key=createHash('sha256').update(`pomodoro_${id}`).digest('hex');
    const batch=writeBatch(store),data={...event(),sourceType:'pomodoro',sourceId:id,amount};
    batch.set(doc(store,`users/alice/completionEvents/${key}`),data);
    batch.set(doc(store,`users/alice/xpLog/${key}`),data);
    total+=amount;batch.set(doc(store,'users/alice/stats/progress'),{xp:total,lastEventId:key,lastUpdated:serverTimestamp()});
    await assertSucceeds(batch.commit());
  }
});
