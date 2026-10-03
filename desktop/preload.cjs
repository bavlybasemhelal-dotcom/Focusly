'use strict';
const {contextBridge, ipcRenderer} = require('electron');
const allowed = new Set(['googleSignIn','schedule','cancel','cancelAll','instant','settings','setStartup','setTray','chooseLocalFile','openLocalFile','verifyInstaller','releaseInfo','notificationStatus']);
contextBridge.exposeInMainWorld('FocuslyDesktop', {
  request: async (operation, json) => {
    if(!allowed.has(operation) || typeof json !== 'string' || json.length > 20000) throw new Error('Invalid desktop request');
    return JSON.stringify(await ipcRenderer.invoke('focusly-request',operation,JSON.parse(json)));
  },
  subscribe: callback => {
    if(typeof callback !== 'function')return;
    ipcRenderer.removeAllListeners('focusly-open');
    ipcRenderer.on('focusly-open',(_,payload)=>callback(payload));
    ipcRenderer.send('focusly-ready');
  }
});
