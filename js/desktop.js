/* VIBES Desktop Sidebar — shared across all pages */
const DESKTOP_CSS = `
  :root{--sidebar-w:240px}
  .desktop-sidebar{display:none}
  .d-logo{font-family:'Bebas Neue',cursive;font-size:30px;letter-spacing:3px;background:linear-gradient(135deg,#ff2d55,#ff6b35);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;padding:0 20px 18px;border-bottom:1px solid #222;margin-bottom:10px;text-decoration:none;display:block}
  .d-nav-item{display:flex;align-items:center;gap:14px;padding:12px 20px;cursor:pointer;color:#888;font-size:15px;font-weight:600;transition:color .15s,background .15s;text-decoration:none;border-left:3px solid transparent}
  .d-nav-item:hover{color:#fff;background:rgba(255,255,255,.04)}
  .d-nav-item.active{color:#fff;border-left-color:#ff2d55;background:rgba(255,45,85,.06)}
  .d-nav-icon{font-size:20px;width:26px;text-align:center}
  .d-nav-badge{background:#ff2d55;color:#fff;font-size:9px;font-weight:700;padding:1px 5px;border-radius:10px;min-width:16px;text-align:center;margin-left:auto;display:none}
  .d-upload-btn{margin:14px 20px;padding:11px;background:#ff2d55;border:none;border-radius:10px;color:#fff;font-family:'DM Sans',sans-serif;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;transition:opacity .2s;width:calc(100% - 40px)}
  .d-upload-btn:hover{opacity:.85}
  .d-sidebar-bottom{margin-top:auto;padding:14px 20px 0;border-top:1px solid #222}
  .d-user-chip{display:flex;align-items:center;gap:10px;cursor:pointer;padding:6px 0}
  .d-user-chip img{width:34px;height:34px;border-radius:50%;object-fit:cover}
  .d-user-dname{font-size:13px;font-weight:600;color:#fff}
  .d-user-handle{font-size:11px;color:#888}
  .d-page-wrap{min-height:100vh;background:var(--bg,#0a0a0a)}
  @media(min-width:1024px){
    body{overflow-x:hidden}
    .bottom-nav{display:none!important}
    .desktop-sidebar{display:flex;flex-direction:column;width:var(--sidebar-w);height:100vh;background:var(--bg,#0a0a0a);border-right:1px solid #222;padding:20px 0;position:fixed;left:0;top:0;bottom:0;z-index:200;overflow-y:auto}
    .desktop-sidebar::-webkit-scrollbar{display:none}
    .d-page-wrap{margin-left:var(--sidebar-w)!important;min-height:100vh}
    .top-nav{left:var(--sidebar-w)!important}
  }
  @media(min-width:768px) and (max-width:1023px){
    :root{--sidebar-w:72px}
    .bottom-nav{display:none!important}
    .desktop-sidebar{display:flex;flex-direction:column;width:var(--sidebar-w);height:100vh;background:var(--bg,#0a0a0a);border-right:1px solid #222;padding:16px 0;position:fixed;left:0;top:0;bottom:0;z-index:200;align-items:center}
    .d-logo{padding:0 0 14px;font-size:18px;letter-spacing:2px;text-align:center;border-bottom:1px solid #222;margin-bottom:10px;width:100%}
    .d-nav-item{padding:12px;justify-content:center;border-left:none;border-radius:12px;margin:2px 6px;width:calc(100% - 12px)}
    .d-nav-item span:not(.d-nav-icon):not(.d-nav-badge){display:none}
    .d-upload-btn{margin:10px 6px;padding:10px;width:calc(100% - 12px);font-size:0;border-radius:12px}
    .d-upload-btn::before{content:'＋';font-size:18px}
    .d-sidebar-bottom{padding:10px 6px 0;width:100%;border-top:1px solid #222;margin-top:auto}
    .d-user-dname,.d-user-handle{display:none}
    .d-page-wrap{margin-left:var(--sidebar-w)!important}
    .top-nav{left:var(--sidebar-w)!important}
  }
`;

function injectDesktopSidebar(activePage='home'){
  const style=document.createElement('style');
  style.textContent=DESKTOP_CSS;
  document.head.appendChild(style);

  const html=`<nav class="desktop-sidebar">
    <a class="d-logo" href="index.html">VIBES</a>
    <a class="d-nav-item ${activePage==='home'?'active':''}" href="index.html"><span class="d-nav-icon">🏠</span><span>Home</span></a>
    <a class="d-nav-item ${activePage==='search'?'active':''}" href="search.html"><span class="d-nav-icon">🔍</span><span>Discover</span></a>
    <a class="d-nav-item ${activePage==='live'?'active':''}" href="live-list.html"><span class="d-nav-icon">🔴</span><span>LIVE</span></a>
    <a class="d-nav-item ${activePage==='notif'?'active':''}" href="notifications.html"><span class="d-nav-icon">🔔</span><span>Notifikasi</span><span class="d-nav-badge" id="dNotifBadge"></span></a>
    <a class="d-nav-item ${activePage==='dm'?'active':''}" href="dm.html"><span class="d-nav-icon">💬</span><span>Mesej</span></a>
    <a class="d-nav-item ${activePage==='profile'?'active':''}" href="profile.html"><span class="d-nav-icon">👤</span><span>Profil</span></a>
    <a class="d-nav-item ${activePage==='wallet'?'active':''}" href="wallet.html"><span class="d-nav-icon">💎</span><span>Wallet</span></a>
    <button class="d-upload-btn" onclick="window.location.href='upload.html'">＋ Upload</button>
    <div class="d-sidebar-bottom">
      <div class="d-user-chip" id="dUserChip" onclick="window.location.href='profile.html'" style="display:none">
        <img id="dSidebarAvatar" src="" alt=""/>
        <div><div class="d-user-dname" id="dSidebarName"></div><div class="d-user-handle" id="dSidebarHandle"></div></div>
      </div>
      <a href="auth.html" id="dLoginChip" style="display:none;padding:8px 0;font-size:13px;color:#ff2d55;font-weight:700;text-decoration:none">Log Masuk →</a>
    </div>
  </nav>`;

  const div=document.createElement('div');
  div.innerHTML=html;
  document.body.insertBefore(div.firstElementChild,document.body.firstChild);

  // Wrap remaining content
  const sidebar=document.querySelector('.desktop-sidebar');
  if(!document.querySelector('.d-page-wrap')){
    const wrap=document.createElement('div');
    wrap.className='d-page-wrap';
    Array.from(document.body.children).filter(c=>c!==sidebar).forEach(c=>wrap.appendChild(c));
    document.body.appendChild(wrap);
  }

  // Load user async
  if(typeof getCurrentUser==='function'){
    getCurrentUser().then(async user=>{
      if(user){
        const profile=typeof getCurrentProfile==='function'?await getCurrentProfile().catch(()=>null):null;
        if(profile){
          const chip=document.getElementById('dUserChip');
          if(chip){
            chip.style.display='flex';
            const av=document.getElementById('dSidebarAvatar');
            if(av&&typeof getAvatarUrl==='function')av.src=getAvatarUrl(profile);
            const nm=document.getElementById('dSidebarName');
            if(nm)nm.textContent=profile.display_name||profile.username;
            const hd=document.getElementById('dSidebarHandle');
            if(hd)hd.textContent='@'+profile.username;
          }
          const login=document.getElementById('dLoginChip');
          if(login)login.style.display='none';
        }
        // Notif badge
        const sb=window.sb;
        if(sb){
          const{count}=await sb.from('notifications').select('*',{count:'exact',head:true}).eq('user_id',user.id).eq('is_read',false).catch(()=>({count:0}));
          if(count>0){const b=document.getElementById('dNotifBadge');if(b){b.textContent=count>99?'99+':count;b.style.display='inline';}}
        }
      }else{
        const chip=document.getElementById('dUserChip');
        const login=document.getElementById('dLoginChip');
        if(chip)chip.style.display='none';
        if(login)login.style.display='block';
      }
    }).catch(()=>{});
  }
}
