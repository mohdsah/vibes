// =============================================
// js/supabase-config.js — VIBES Platform
// =============================================

const SUPABASE_URL = 'https://dbgtrsjlsqgsnfcldzyu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRiZ3Ryc2psc3Fnc25mY2xkenl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNDMyMjksImV4cCI6MjA5MDcxOTIyOX0.ioQ8BwYi9lOrkvfstgEfQErjpq1lbLbAqH87rSHds8Q';

const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ─── Auth helpers ───────────────────────────
async function getCurrentUser() {
  const { data: { user } } = await sb.auth.getUser();
  return user;
}

async function getCurrentProfile() {
  const user = await getCurrentUser();
  if (!user) return null;
  const { data } = await sb.from('profiles').select('*').eq('id', user.id).single();
  return data;
}

// ─── Format number ───────────────────────────
function formatCount(n) {
  if (!n) return '0';
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return n.toString();
}

// ─── Relative time ───────────────────────────
function timeAgo(dateStr) {
  const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

// ─── Avatar fallback ─────────────────────────
function getAvatarUrl(profile) {
  if (profile?.avatar_url) return profile.avatar_url;
  const name = encodeURIComponent(profile?.display_name || profile?.username || 'U');
  return `https://ui-avatars.com/api/?name=${name}&background=random&color=fff&bold=true&size=128`;
}

// ─── DILET RANK SYSTEM ───────────────────────
// Rank berdasarkan jumlah coins yang pernah dihantar sebagai gift
const DILET_RANKS = [
  { name: 'Batu',    min: 0,      emoji: '🪨', color: '#888888',  badge: '#555' },
  { name: 'Gangsa',  min: 100,    emoji: '🥉', color: '#cd7f32',  badge: '#7a4a1a' },
  { name: 'Perak',   min: 500,    emoji: '🥈', color: '#c0c0c0',  badge: '#6a6a6a' },
  { name: 'Emas',    min: 2000,   emoji: '🥇', color: '#ffd700',  badge: '#8a6a00' },
  { name: 'Zamrud',  min: 5000,   emoji: '💚', color: '#50c878',  badge: '#1a6a30' },
  { name: 'Nilam',   min: 10000,  emoji: '💙', color: '#4169e1',  badge: '#0a2a8a' },
  { name: 'Berlian', min: 25000,  emoji: '💎', color: '#b9f2ff',  badge: '#0090aa' },
  { name: 'Legenda', min: 100000, emoji: '👑', color: '#ff2d55',  badge: '#8a001a' },
];

function getDiletRank(totalCoinsSpent = 0) {
  let rank = DILET_RANKS[0];
  for (const r of DILET_RANKS) {
    if (totalCoinsSpent >= r.min) rank = r;
  }
  return rank;
}

function getNextRank(totalCoinsSpent = 0) {
  for (let i = DILET_RANKS.length - 1; i >= 0; i--) {
    if (totalCoinsSpent < DILET_RANKS[i].min) {
      return DILET_RANKS[i];
    }
  }
  return null; // Already max rank
}

function getRankProgress(totalCoinsSpent = 0) {
  const current = getDiletRank(totalCoinsSpent);
  const next = getNextRank(totalCoinsSpent);
  if (!next) return 100;
  const range = next.min - current.min;
  const progress = totalCoinsSpent - current.min;
  return Math.min(100, Math.round((progress / range) * 100));
}

// Render rank badge HTML
function renderRankBadge(totalCoinsSpent = 0, size = 'sm') {
  const rank = getDiletRank(totalCoinsSpent);
  const isLg = size === 'lg';
  return `<span class="rank-badge" style="
    background:${rank.badge};
    border:1px solid ${rank.color};
    color:${rank.color};
    font-size:${isLg ? '13px' : '11px'};
    padding:${isLg ? '4px 10px' : '2px 7px'};
    border-radius:20px;
    font-weight:700;
    white-space:nowrap;
    display:inline-flex;
    align-items:center;
    gap:4px;
  ">${rank.emoji} ${rank.name}</span>`;
}
