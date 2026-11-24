self.addEventListener('install',event=>{self.skipWaiting();});
self.addEventListener('activate',event=>{event.waitUntil(self.clients.claim());});
self.addEventListener('fetch',event=>{});
self.addEventListener('push',event=>{
  let data={title:'EFFETTO LAB',body:'Tienes una nueva notificación.',url:'/'};
  try{if(event.data)data={...data,...event.data.json()}}catch(_){try{data.body=event.data.text()}catch(__){}}
  event.waitUntil(self.registration.showNotification(data.title||'EFFETTO LAB',{
    body:data.body||'Tienes una nueva notificación.',
    icon:'/icon-192.png',badge:'/icon-192.png',
    data:{url:data.url||'/'},tag:data.tag||undefined,
    renotify:false
  }));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const target=event.notification.data?.url||'/';
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
    for(const client of list){if('focus' in client){client.navigate(target);return client.focus();}}
    return clients.openWindow?clients.openWindow(target):undefined;
  }));
});
