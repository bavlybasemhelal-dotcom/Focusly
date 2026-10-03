import {packager} from '@electron/packager';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import path from 'node:path';
const directory=path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/,'$1'));
const root=path.resolve(directory,'..');
const source=readFileSync(path.join(root,'lib/firebase_options.dart'),'utf8');
const web=source.match(/static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/)[1];
const config={};
for(const match of web.matchAll(/(apiKey|appId|messagingSenderId|projectId|authDomain|storageBucket|measurementId):\s*'([^']+)'/g))config[match[1]]=match[2];
writeFileSync(path.join(directory,'firebase-config.json'),JSON.stringify(config,null,2));
for(const file of ['web/main.dart.js','web/sdk/firebase.js','web/assets/assets/scripts/windows_notifications.ps1']) {
  if(!existsSync(path.join(directory,file)))throw new Error(`Missing release asset: ${file}`);
}
const outputs=await packager({dir:directory,out:path.join(directory,'out'),name:'Focusly',executableName:'focusly',
  platform:'win32',arch:'x64',electronVersion:'44.5.1',appVersion:'1.1.0',overwrite:true,asar:false,prune:false,
  icon:path.join(root,'windows/runner/resources/app_icon.ico'),
  ignore:[/^\/node_modules($|\/)/,/^\/out($|\/)/,/^\/test($|\/)/,/^\/(build-sdk|package-desktop|build-desktop)/,/package-lock\.json$/],
  win32metadata:{CompanyName:'Focusly',FileDescription:'Focusly productivity app',ProductName:'Focusly'}});
for(const output of outputs)process.stdout.write(`Desktop release: ${output}\n`);
