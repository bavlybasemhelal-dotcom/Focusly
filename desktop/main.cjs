'use strict';
const {app,BrowserWindow,ipcMain,shell,dialog,Tray,Menu,Notification} = require('electron');
const {createServer}=require('node:http');
const {readFileSync,existsSync,statSync,createReadStream,writeFileSync}=require('node:fs');
const {randomBytes,createHash}=require('node:crypto');
const {spawn}=require('node:child_process');
const path=require('node:path');
const {assetPath,validateNotification}=require('./runtime.cjs');
const smoke=process.argv.includes('--smoke');
const profile=process.argv.find(arg=>arg.startsWith('--focusly-profile='));
if(profile)app.setPath('userData',path.resolve(profile.slice('--focusly-profile='.length)));
app.setAppUserModelId('Focusly.Focusly');
const port=54873, origin=`http://localhost:${port}`;
let window,server,tray,quitting=false,googlePending=null,pendingPayload=null;
let preferences={tray:true};
function preferenceFile(){return path.join(app.getPath('userData'),'desktop-preferences.json');}
function savePreferences(){writeFileSync(preferenceFile(),JSON.stringify(preferences));}
function diagnostic(kind,details={}) {
  try {
    const file=path.join(app.getPath('userData'),'diagnostics.jsonl');
    const lines=existsSync(file)?readFileSync(file,'utf8').split('\n').filter(Boolean).slice(-49):[];
    lines.push(JSON.stringify({at:new Date().toISOString(),version:app.getVersion(),kind,...details}));
    writeFileSync(file,lines.join('\n')+'\n');
  } catch(_) {}
}
app.on('render-process-gone',(_event,_contents,details)=>diagnostic('rendererStopped',{reason:details.reason,exitCode:details.exitCode}));
app.on('child-process-gone',(_event,details)=>diagnostic('childStopped',{type:details.type,reason:details.reason}));
function openPayload(raw) {
  try {
    const url=new URL(raw);
    if(url.protocol!=='focusly:' || url.hostname!=='open')return;
    const account=url.searchParams.get('account'), payload=url.searchParams.get('payload');
    if(!account || !payload || payload.length>500)return;
    pendingPayload=`account=${account}|${payload}`;
    window?.show();
    window?.webContents.send('focusly-open',pendingPayload);
  }catch(_){}
}
async function external(url) { const parsed=new URL(url); if(['https:','http:'].includes(parsed.protocol))return shell.openExternal(parsed.href); }
function toast(request) {
  if(process.platform!=='win32')throw new Error('Windows native notifications are unavailable');
  const script=path.join(__dirname,'web','assets','assets','scripts','windows_notifications.ps1');
  return new Promise((resolve,reject)=>{
    const child=spawn('powershell.exe',['-WindowStyle','Hidden','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',script,
      '-RequestBase64',Buffer.from(JSON.stringify(request)).toString('base64')],{windowsHide:true,stdio:['ignore','pipe','pipe'],shell:false});
    let stdout='';child.stdout.on('data',chunk=>{if(stdout.length<2000)stdout+=chunk;});
    let stderr='';child.stderr.on('data',chunk=>{if(stderr.length<8000)stderr+=chunk;});
    const timeout=setTimeout(()=>{child.kill();reject(new Error('Notification helper timed out'));},15000);
    child.on('error',error=>{clearTimeout(timeout);reject(error);});
    child.on('exit',code=>{clearTimeout(timeout);if(code!==0){reject(new Error(`Notification helper failed (${code})`));return;}
      try {resolve(request.action==='status'?JSON.parse(stdout):{scheduled:true});}catch(_){reject(new Error('Invalid notification status'));}});
  });
}
function authHtml(state) {
  const config=JSON.stringify(JSON.parse(readFileSync(path.join(__dirname,'firebase-config.json'),'utf8')));
  return `<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>Focusly · Google</title>
  <style>body{background:#101827;color:#fff;font:18px Arial;display:grid;place-items:center;min-height:90vh}button{padding:16px;border-radius:12px;font-size:18px}main{max-width:550px;text-align:center}</style>
  <main><h1>Focusly</h1><p id="status">سجّل الدخول في متصفحك، ثم ارجع للبرنامج.</p><button id="login">متابعة باستخدام Google · Continue with Google</button></main>
  <script src="/sdk/google.js"></script><script>
  const {app,auth}=focuslyGoogle;const firebaseApp=app.initializeApp(${config});const session=auth.getAuth(firebaseApp);
  auth.setPersistence(session,auth.inMemoryPersistence);
  document.querySelector('#login').onclick=async()=>{
    const button=document.querySelector('#login');button.disabled=true;
    try{const result=await auth.signInWithPopup(session,new auth.GoogleAuthProvider());const credential=auth.GoogleAuthProvider.credentialFromResult(result);
      const response=await fetch('/callback',{method:'POST',headers:{'Content-Type':'application/json','X-Focusly-State':${JSON.stringify(state)}},body:JSON.stringify({idToken:credential.idToken,accessToken:credential.accessToken})});
      if(!response.ok)throw new Error('Callback failed');await auth.signOut(session);document.querySelector('#status').textContent='تم الدخول. تقدر ترجع للبرنامج · You may return to Focusly';button.hidden=true;
    }catch(error){document.querySelector('#status').textContent='تعذر الدخول. اضغط للمحاولة مرة أخرى · Sign-in failed; retry';button.disabled=false;}
  };</script></html>`;
}
async function googleSignIn() {
  if(googlePending)return googlePending;
  googlePending=(async()=>{
    const state=randomBytes(32).toString('hex');let authServer,timeout;
    try {
      return await new Promise((resolve,reject)=>{
        authServer=createServer(async(req,res)=>{
          res.setHeader('Cache-Control','no-store');res.setHeader('Referrer-Policy','no-referrer');
          const url=new URL(req.url,'http://localhost');
          if(req.method==='GET' && url.pathname==='/auth' && url.searchParams.get('state')===state){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(authHtml(state));return;}
          if(req.method==='GET' && url.pathname==='/sdk/google.js'){res.setHeader('Content-Type','text/javascript');createReadStream(path.join(__dirname,'web','sdk','google.js')).pipe(res);return;}
          if(req.method==='POST' && url.pathname==='/callback' && req.headers['x-focusly-state']===state && req.headers.origin===`http://localhost:${authServer.address().port}`){
            try {let body='';for await(const chunk of req){body+=chunk;if(body.length>12000)throw new Error('Body too large');}
              const data=JSON.parse(body);if(typeof data.idToken!=='string' || data.idToken.length>8000)throw new Error('Invalid credential');
              res.end('{}');resolve({idToken:data.idToken,accessToken:typeof data.accessToken==='string'?data.accessToken:null});
            }catch(_){res.statusCode=400;res.end();}return;
          }
          res.statusCode=403;res.end();
        });
        authServer.on('error',reject);authServer.listen(0,'127.0.0.1',()=>{
          shell.openExternal(`http://localhost:${authServer.address().port}/auth?state=${state}`).catch(reject);
        });
        timeout=setTimeout(()=>resolve({cancelled:true}),120000);
      });
    }finally{clearTimeout(timeout);authServer?.close();googlePending=null;}
  })();return googlePending;
}
function authorized(event){return window && event.sender===window.webContents && event.senderFrame?.url.startsWith(origin+'/');}
ipcMain.handle('focusly-request',async(event,operation,args)=>{
  if(!authorized(event) || !args || typeof args!=='object')throw new Error('Unauthorized desktop request');
  if(operation==='googleSignIn')return googleSignIn();
  if(operation==='schedule')return toast({action:'schedule',...validateNotification(args)});
  if(operation==='cancel'){if(!Number.isInteger(args.id))throw new Error('Invalid ID');return toast({action:'cancel',id:args.id});}
  if(operation==='cancelAll')return toast({action:'cancelAll'});
  if(operation==='instant') {
    const data=validateNotification(args);const notification=new Notification({title:data.title,body:data.body});
    notification.on('click',()=>{window?.show();if(data.payload)window?.webContents.send('focusly-open',data.payload);});notification.show();return {sentToOs:true};
  }
  if(operation==='settings')return {version:app.getVersion(),startup:app.getLoginItemSettings().openAtLogin,tray:preferences.tray};
  if(operation==='notificationStatus')return toast({action:'status'});
  if(operation==='releaseInfo') {
    const response=await fetch('https://focusly-87187.web.app/releases/windows.json',{signal:AbortSignal.timeout(10000),redirect:'error'});
    if(!response.ok)throw new Error('Release information unavailable');
    const content=await response.text();
    if(content.length>5000)throw new Error('Invalid release information');
    const release=JSON.parse(content);
    if(!/^\d+\.\d+\.\d+$/.test(release.version) || !/^[a-fA-F0-9]{64}$/.test(release.sha256))throw new Error('Invalid release information');
    return {version:release.version,sha256:release.sha256};
  }
  if(operation==='setStartup'){if(typeof args.enabled!=='boolean')throw new Error('Invalid preference');app.setLoginItemSettings({openAtLogin:args.enabled,path:process.execPath,args:['--background']});return {};}
  if(operation==='setTray'){if(typeof args.enabled!=='boolean')throw new Error('Invalid preference');preferences.tray=args.enabled;savePreferences();return {};}
  if(operation==='chooseLocalFile'){const result=await dialog.showOpenDialog(window,{properties:['openFile'],filters:[{name:'Documents & media',extensions:['pdf','txt','md','csv','png','jpg','jpeg','mp3','mp4','docx','xlsx','pptx']}]});return {path:result.canceled?null:result.filePaths[0]};}
  if(operation==='openLocalFile'){const target=path.resolve(String(args.path));if(!['.pdf','.txt','.md','.csv','.png','.jpg','.jpeg','.mp3','.mp4','.docx','.xlsx','.pptx'].includes(path.extname(target).toLowerCase()) || !statSync(target).isFile())throw new Error('Unsupported attachment');const error=await shell.openPath(target);if(error)throw new Error('File could not be opened');return {};}
  if(operation==='verifyInstaller') {
    if(typeof args.sha256!=='string' || !/^[a-f0-9]{64}$/i.test(args.sha256))throw new Error('Enter a SHA-256 hash');
    const selected=await dialog.showOpenDialog(window,{properties:['openFile'],filters:[{name:'Focusly installer',extensions:['exe']}]});
    if(selected.canceled)return {cancelled:true};const target=selected.filePaths[0];const hash=createHash('sha256');for await(const chunk of createReadStream(target))hash.update(chunk);
    const sha256=hash.digest('hex');return {matches:sha256.toLowerCase()===args.sha256.toLowerCase(),sha256,path:target};
  }
  throw new Error('Unsupported desktop operation');
});
ipcMain.on('focusly-ready',event=>{if(authorized(event) && pendingPayload){window.webContents.send('focusly-open',pendingPayload);pendingPayload=null;}});
if(!app.requestSingleInstanceLock()){app.quit();}else{
  app.on('second-instance',(_,argv)=>{window?.show();const uri=argv.find(arg=>arg.startsWith('focusly://'));if(uri)openPayload(uri);});
  app.on('before-quit',()=>{quitting=true;server?.close();});
  app.whenReady().then(async()=>{
    try{preferences={...preferences,...JSON.parse(readFileSync(preferenceFile(),'utf8'))};}catch(_){}
    if(!smoke)app.setAsDefaultProtocolClient('focusly');
    const root=path.join(__dirname,'web');
    const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf'};
    server=createServer((req,res)=>{try{
      if(!['GET','HEAD'].includes(req.method) || req.headers.host!==`localhost:${port}`){res.statusCode=403;res.end();return;}
      const file=assetPath(root,req.url);if(!existsSync(file) || !statSync(file).isFile()){res.statusCode=404;res.end();return;}
      res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Cache-Control','no-cache');
      res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://accounts.google.com; style-src 'self' 'unsafe-inline'; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.firebaseapp.com; img-src 'self' data: blob: https:; font-src 'self' data:; frame-src https://*.firebaseapp.com https://accounts.google.com; worker-src 'self' blob:;");
      if(req.method==='HEAD')res.end();else createReadStream(file).pipe(res);
    }catch(_){res.statusCode=400;res.end();}});
    await new Promise((resolve,reject)=>{server.on('error',reject);server.listen(port,'127.0.0.1',resolve);});
    window=new BrowserWindow({width:1280,height:900,minWidth:420,minHeight:600,show:!smoke && !process.argv.includes('--background'),title:'Focusly',icon:path.join(root,'favicon.png'),
      webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,webSecurity:true,spellcheck:false,backgroundThrottling:false}});
    window.webContents.setWindowOpenHandler(({url})=>{external(url).catch(()=>{});return {action:'deny'};});
    window.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith(origin+'/')){event.preventDefault();external(url).catch(()=>{});}});
    window.webContents.session.setPermissionRequestHandler((contents,permission,callback)=>callback(contents===window.webContents && contents.getURL().startsWith(origin+'/') && permission==='notifications'));
    window.on('close',event=>{if(!quitting && preferences.tray && !smoke){event.preventDefault();window.hide();}});
    tray=new Tray(path.join(root,'favicon.png'));tray.setToolTip('Focusly');tray.setContextMenu(Menu.buildFromTemplate([{label:'فتح Focusly · Open',click:()=>window.show()},
      {label:'إغلاق البرنامج · Quit',click:()=>{quitting=true;app.quit();}}]));tray.on('double-click',()=>window.show());
    await window.loadURL(origin+'/');
    const uri=process.argv.find(arg=>arg.startsWith('focusly://'));if(uri)openPayload(uri);
    if(smoke)window.webContents.on('console-message',event=>{if(event.level==='error')process.stderr.write('Renderer reported an error\n');});
  }).catch(()=>{if(!smoke)dialog.showErrorBox('Focusly','تعذر تشغيل البرنامج. أغلق النسخة الأخرى أو تحقق من منفذ 54873 ثم حاول مرة أخرى.');app.quit();});
}
