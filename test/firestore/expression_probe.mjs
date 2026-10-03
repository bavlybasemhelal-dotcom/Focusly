import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, Timestamp} from 'firebase/firestore';
import {createHash} from 'node:crypto';
const key = createHash('sha256').update('task_t').digest('hex');
const expressions = [
  `hashing.sha256('task_t'.toUtf8()).toHexString() == '${key}'`,
  "duration.value(0, 'm') == duration.value(0, 's')",
  "request.resource.data.weekStartAt.date() == request.resource.data.weekStartAt",
  'int(request.resource.data.weekStartAt.toMillis() / 86400000) % 7 == 2',
  'request.resource.data.weekStartAt <= request.time',
];
const start = new Date(); start.setUTCHours(0, 0, 0, 0); start.setUTCDate(start.getUTCDate() - (start.getUTCDay() + 1) % 7);
for (let index = 0; index < expressions.length; index++) {
  const env = await initializeTestEnvironment({projectId: `demo-focusly-expression-${index}`,firestore:{host:'127.0.0.1',port:8080,rules:`rules_version = '2'; service cloud.firestore { match /databases/{database}/documents { match /probe/{id} { allow create: if ${expressions[index]}; } } }`}});
  try { await setDoc(doc(env.authenticatedContext('alice').firestore(),'probe/p'), {weekStartAt:Timestamp.fromDate(start)}); console.log(index, 'PASS'); }
  catch (error) { console.log(index, 'FAIL',error.code); }
  await env.cleanup();
}
