// =============================================
// js/nav.js — Shared bottom nav + notif badge
// Include AFTER supabase-config.js
// =============================================

// Inject bottom nav into any page
// Usage: <div id="bottomNav"></div> + renderBottomNav('home')
const NAV_ITEMS = [
  { id: 'home',   href: 'index.html',         icon: '🏠', label: 'Home' },
  { id: 'search', href: 'search.html',         icon: '🔍', label: 'Discover' },
  { id: 'upload', href: 'upload.html',         icon: null,  label: null }, // special
  { id: 'live',   href: 'live-list.html',      icon: '🔴', label: 'Live' },
  { id: 'profile',href: 'profile.html',        icon: '👤', label: 'Profile' },
];

function renderBottomNav(activePage) {
  const el = document.getElementById('bottomNav');
  if (!el) return;

  el.className = 'bottom-nav';
  el.innerHTML = NAV_ITEMS.map(item => {
    const isActive = item.id === activePage;
    if (!item.icon) {
      // Upload button (special)
      return `<a class="bottom-tab ${isActive ? 'active' : ''}" href="${item.href}">
        <div class="upload-tab">＋</div>
      </a>`;
    }
    const badge = item.id === 'notif'
      ? `<span class="notif-dot" id="globalNotifBadge"></span>`
      : '';
    return `<a class="bottom-tab ${isActive ? 'active' : ''}" href="${item.href}">
      ${item.icon}<span>${item.label}</span>${badge}
    </a>`;
  }).join('');
}

// Load unread notif count and show badge on bell icon
async function loadGlobalNotifBadge() {
  const user = await getCurrentUser();
  if (!user) return;
  const { count } = await sb.from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('is_read', false);
  if (count > 0) {
    document.querySelectorAll('.globalNotifBadge, #globalNotifBadge, #notifBadge').forEach(el => {
      if (el) { el.textContent = count > 99 ? '99+' : count; el.style.display = 'block'; }
    });
  }
}

// Auto-load badge on DOMContentLoaded
document.addEventListener('DOMContentLoaded', () => {
  loadGlobalNotifBadge();
  // Refresh every 30s
  setInterval(loadGlobalNotifBadge, 30000);
});
