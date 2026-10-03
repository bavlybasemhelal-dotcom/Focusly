'use strict';
const {build} = require('esbuild');
const {mkdirSync,writeFileSync} = require('node:fs');
const path = require('node:path');
const output = path.join(__dirname,'..','web','sdk');
mkdirSync(output,{recursive:true});
const entry = `import * as app from 'firebase/app'; import * as auth from 'firebase/auth'; import * as firestore from 'firebase/firestore';
globalThis.firebase_core=app; globalThis.firebase_auth=auth; globalThis.firebase_firestore=firestore; globalThis.focuslySdkReady=true;`;
const authEntry = `import * as app from 'firebase/app'; import * as auth from 'firebase/auth'; globalThis.focuslyGoogle={app,auth};`;
Promise.all([
  build({stdin:{contents:entry,resolveDir:__dirname},bundle:true,minify:true,platform:'browser',format:'iife',outfile:path.join(output,'firebase.js')}),
  build({stdin:{contents:authEntry,resolveDir:__dirname},bundle:true,minify:true,platform:'browser',format:'iife',outfile:path.join(output,'google.js')})
]).catch(()=>{process.exitCode=1;});
