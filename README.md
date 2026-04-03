# 🎬 VIBES — TikTok-style Video Sharing Platform

Platform perkongsian video pendek seperti TikTok, dibina dengan vanilla JS + Supabase + Netlify.

---

## 🗂️ Struktur Fail

```
vibes/
├── index.html          → Feed utama (For You page)
├── auth.html           → Login / Register
├── upload.html         → Upload video
├── profile.html        → Profil pengguna
├── search.html         → Carian & Discover
├── video.html          → Tontonkan video single
├── js/
│   └── supabase-config.js  → Supabase credentials & helpers
├── netlify.toml        → Netlify config
└── supabase_schema.sql → Schema database lengkap
```

---

## 🚀 Cara Setup

### 1. Setup Supabase

1. Pergi ke [supabase.com](https://supabase.com) → Create new project
2. Pergi ke **SQL Editor**
3. Copy semua kod dari `supabase_schema.sql` dan jalankan
4. Pergi ke **Settings > API** → salin:
   - **Project URL** (contoh: `https://abcxyz.supabase.co`)
   - **anon/public key**

### 2. Configure Credentials

Buka `js/supabase-config.js` dan ganti:

```js
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

### 3. Supabase Storage

Dalam Supabase dashboard → Storage, pastikan bucket ini sudah dibuat (schema SQL akan auto-create):
- `videos` (public)
- `thumbnails` (public)  
- `avatars` (public)

### 4. Deploy ke Netlify

**Cara 1 — Drag & Drop (Mudah):**
1. Pergi ke [netlify.com](https://netlify.com)
2. Log in → "Add new site" → "Deploy manually"
3. Drag folder `vibes/` ke Netlify
4. Done! 🎉

**Cara 2 — GitHub + CI/CD:**
1. Push folder ke GitHub repo
2. Netlify → "Import from Git"
3. Pilih repo, build settings akan auto-detect dari `netlify.toml`

---

## ✨ Features

| Feature | Status |
|---------|--------|
| ✅ Register / Login | Supabase Auth |
| ✅ Video Feed (scroll snap) | Auto-play on scroll |
| ✅ Upload Video | Supabase Storage |
| ✅ Like / Unlike | Real-time count |
| ✅ Comments | Drawer UI |
| ✅ Follow / Unfollow | Profile stats |
| ✅ User Profile | Grid view |
| ✅ Search | Users + Videos |
| ✅ Share Video | Native share API |
| ✅ Avatar Upload | Supabase Storage |
| ✅ Infinity Scroll | Pagination |

---

## 🔧 Customization

### Tukar nama app
Cari `VIBES` dalam semua fail HTML dan ganti dengan nama kau.

### Tukar warna
Dalam setiap HTML file, cari `:root` dan ubah:
```css
--accent: #ff2d55;   /* Warna utama (merah) */
--accent2: #ff6b35;  /* Warna gradient */
```

### Tambah fitur notifikasi
Tambah table `notifications` dalam Supabase dan subscribe ke Supabase Realtime.

---

## 📱 Mobile First

Platform ini dioptimasi untuk mobile dengan:
- Scroll snap untuk video feed
- Touch-friendly UI
- Native share API
- Portrait video format (9:16)

---

## 🛡️ Security

- Row Level Security (RLS) diaktifkan untuk semua table
- Storage bucket policies dikonfigurasi
- Auth trigger auto-create profile
- Input validation di frontend & database constraints

---

Built with ❤️ using Vanilla JS + Supabase + Netlify
