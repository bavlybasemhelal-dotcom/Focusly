'use strict';
const path = require('node:path');
function assetPath(root, url) {
  const pathname = decodeURIComponent(new URL(url,'http://localhost').pathname);
  if(pathname.includes('\0') || pathname.includes('\\'))throw new Error('Invalid path');
  const target = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  const relative = path.relative(root,target);
  if(relative.startsWith('..') || path.isAbsolute(relative))throw new Error('Invalid path');
  return target;
}
function validateNotification(args) {
  if(!Number.isInteger(args.id) || args.id<0 || args.id>0x7fffffff)throw new Error('Invalid notification ID');
  if(typeof args.title!=='string' || args.title.length>500 || typeof args.body!=='string' || args.body.length>2000)throw new Error('Invalid notification text');
  if(args.date!=null) {
    const time=Date.parse(args.date);
    if(!Number.isFinite(time) || time>Date.now()+32*86400000)throw new Error('Invalid notification date');
  }
  if(args.payload!=null && (typeof args.payload!=='string' || args.payload.length>500))throw new Error('Invalid notification payload');
  return {id:args.id,title:args.title,body:args.body,...(args.date!=null?{date:args.date}:{}),...(args.payload!=null?{payload:args.payload}:{})};
}
module.exports={assetPath,validateNotification};
