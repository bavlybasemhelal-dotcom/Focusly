'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {assetPath,validateNotification}=require('../runtime.cjs');
test('asset root serves a known local file and never escapes its directory',()=>{
  const root=path.resolve('C:/focusly/web');
  assert.equal(assetPath(root,'/'),path.join(root,'index.html'));
  assert.equal(assetPath(root,'/assets/fonts/Cairo.ttf'),path.join(root,'assets/fonts/Cairo.ttf'));
  for(const url of ['/..%2f..%2fwindows/system.ini','/%5C..%5Csecret','/%00','/%ZZ'])assert.throws(()=>assetPath(root,url));
});
test('native notification arguments reject malformed IDs, dates and oversized payloads',()=>{
  const valid={id:12,title:'عادتك',body:'تذكير',date:new Date(Date.now()+60000).toISOString(),payload:'account=u|habit:h'};
  assert.deepEqual(validateNotification(valid),valid);
  for(const delta of [{id:-1},{id:3.5},{date:'invalid'},{date:new Date(Date.now()+33*86400000).toISOString()},
    {title:'x'.repeat(501)},{body:'x'.repeat(2001)},{payload:15},{payload:'x'.repeat(501)}])assert.throws(()=>validateNotification({...valid,...delta}));
});
