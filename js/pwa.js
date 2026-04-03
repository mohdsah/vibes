// =============================================
// js/pwa.js — PWA install prompt + service worker
// Include in every page: <script src="js/pwa.js"></script>
// =============================================

// Register service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('SW registered:', reg.scope))
      .catch(err => console.log('SW failed:', err));
  });
}

// Install prompt banner
let deferredPrompt = null;
let installBannerShown = false;

window.addEventListener('beforeinstallprompt', e => {
  e.preventDefault();
  deferredPrompt = e;
  if (!installBannerShown) showInstallBanner();
});

function showInstallBanner() {
  // Don't show if already installed
  if (window.matchMedia('(display-mode: standalone)').matches) return;
  if (localStorage.getItem('pwa_dismissed')) return;

  installBannerShown = true;

  const banner = document.createElement('div');
  banner.id = 'pwaBanner';
  banner.innerHTML = `
    <div style="
      position:fixed; bottom:80px; left:12px; right:12px; z-index:9999;
      background:linear-gradient(135deg,#1a0a10,#0a0a1a);
      border:1px solid #ff2d55;
      border-radius:16px; padding:14px 16px;
      display:flex; align-items:center; gap:12px;
      box-shadow:0 8px 32px rgba(255,45,85,0.3);
      animation:slideUp 0.4s ease;
    ">
      <div style="font-size:36px;flex-shrink:0">📲</div>
      <div style="flex:1;min-width:0">
        <div style="font-size:14px;font-weight:700;color:white;margin-bottom:2px">Install VIBES App</div>
        <div style="font-size:12px;color:rgba(255,255,255,0.6)">Pasang untuk pengalaman lebih laju!</div>
      </div>
      <div style="display:flex;flex-direction:column;gap:6px;flex-shrink:0">
        <button onclick="installPWA()" style="
          background:linear-gradient(135deg,#ff2d55,#ff6b35);
          border:none;border-radius:8px;color:white;
          font-family:'DM Sans',sans-serif;font-size:12px;font-weight:700;
          padding:7px 14px;cursor:pointer;white-space:nowrap;
        ">Install</button>
        <button onclick="dismissInstall()" style="
          background:rgba(255,255,255,0.1);border:none;border-radius:8px;
          color:rgba(255,255,255,0.5);font-size:11px;padding:4px 8px;cursor:pointer;
        ">Nanti</button>
      </div>
    </div>
    <style>
      @keyframes slideUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}
    </style>
  `;
  document.body.appendChild(banner);
}

async function installPWA() {
  const banner = document.getElementById('pwaBanner');
  if (banner) banner.remove();
  if (!deferredPrompt) return;
  deferredPrompt.prompt();
  const { outcome } = await deferredPrompt.userChoice;
  deferredPrompt = null;
  if (outcome === 'accepted') {
    console.log('PWA installed!');
  }
}

function dismissInstall() {
  const banner = document.getElementById('pwaBanner');
  if (banner) banner.remove();
  localStorage.setItem('pwa_dismissed', '1');
}

// Hide banner if already in standalone
if (window.matchMedia('(display-mode: standalone)').matches) {
  window.addEventListener('DOMContentLoaded', () => {
    const banner = document.getElementById('pwaBanner');
    if (banner) banner.remove();
  });
}

// iOS install instructions
window.addEventListener('DOMContentLoaded', () => {
  const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const isInStandalone = window.navigator.standalone;
  const dismissed = localStorage.getItem('ios_pwa_dismissed');

  if (isIOS && !isInStandalone && !dismissed) {
    const tip = document.createElement('div');
    tip.id = 'iosTip';
    tip.innerHTML = `
      <div style="
        position:fixed;bottom:80px;left:12px;right:12px;z-index:9999;
        background:rgba(20,20,20,0.97);border:1px solid #333;
        border-radius:16px;padding:14px 16px;
        display:flex;align-items:center;gap:12px;
        box-shadow:0 8px 32px rgba(0,0,0,0.5);
        animation:slideUp 0.4s ease;
      ">
        <div style="font-size:32px;flex-shrink:0">📱</div>
        <div style="flex:1">
          <div style="font-size:13px;font-weight:700;color:white;margin-bottom:3px">Install VIBES di iPhone</div>
          <div style="font-size:12px;color:rgba(255,255,255,0.6)">Tap <strong style="color:white">⬆️ Share</strong> → <strong style="color:white">Add to Home Screen</strong></div>
        </div>
        <button onclick="document.getElementById('iosTip').remove();localStorage.setItem('ios_pwa_dismissed','1')" style="
          background:none;border:none;color:rgba(255,255,255,0.4);font-size:22px;cursor:pointer;
        ">✕</button>
      </div>
    `;
    document.body.appendChild(tip);
    setTimeout(() => {
      const el = document.getElementById('iosTip');
      if (el) el.remove();
    }, 8000);
  }
});
