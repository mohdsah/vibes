-- =============================================
-- VIBES v11 — Status Posts + Live Text + Highlights
-- Run dalam Supabase SQL Editor (existing project)
-- =============================================

-- ─── STATUS POSTS (24 jam, macam Stories) ────
CREATE TABLE IF NOT EXISTS status_posts (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content     TEXT,                        -- text content
  image_url   TEXT,                        -- optional image
  bg_color    TEXT DEFAULT '#111111',      -- background color
  text_color  TEXT DEFAULT '#ffffff',
  font_size   TEXT DEFAULT 'medium',
  emoji       TEXT,                        -- featured emoji
  type        TEXT DEFAULT 'text' CHECK (type IN ('text','image','emoji')),
  views_count INT DEFAULT 0,
  expires_at  TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS status_user_idx ON status_posts(user_id, expires_at);
CREATE INDEX IF NOT EXISTS status_active_idx ON status_posts(expires_at) WHERE expires_at > NOW();

ALTER TABLE status_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "status_select"  ON status_posts FOR SELECT USING (TRUE);
CREATE POLICY "status_insert"  ON status_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "status_delete"  ON status_posts FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "status_update"  ON status_posts FOR UPDATE USING (auth.uid() = user_id);

-- STATUS VIEWS (track who viewed)
CREATE TABLE IF NOT EXISTS status_views (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  status_id  UUID REFERENCES status_posts(id) ON DELETE CASCADE NOT NULL,
  viewer_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  viewed_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(status_id, viewer_id)
);

ALTER TABLE status_views ENABLE ROW LEVEL SECURITY;
CREATE POLICY "status_views_insert" ON status_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);
CREATE POLICY "status_views_select" ON status_views FOR SELECT USING (
  status_id IN (SELECT id FROM status_posts WHERE user_id = auth.uid())
  OR auth.uid() = viewer_id
);

-- Auto increment views_count
CREATE OR REPLACE FUNCTION increment_status_views()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE status_posts SET views_count = views_count + 1 WHERE id = NEW.status_id;
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_status_view ON status_views;
CREATE TRIGGER on_status_view
  AFTER INSERT ON status_views
  FOR EACH ROW EXECUTE FUNCTION increment_status_views();

-- ─── LIVE TEXT ROOMS (tanpa video) ───────────
CREATE TABLE IF NOT EXISTS live_text_rooms (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  host_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title       TEXT NOT NULL,
  topic       TEXT,
  bg_emoji    TEXT DEFAULT '💬',
  bg_color    TEXT DEFAULT '#111111',
  viewer_count INT DEFAULT 0,
  msg_count   INT DEFAULT 0,
  status      TEXT DEFAULT 'live' CHECK (status IN ('live','ended')),
  started_at  TIMESTAMPTZ DEFAULT NOW(),
  ended_at    TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS live_text_messages (
  id       UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id  UUID REFERENCES live_text_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content  TEXT NOT NULL,
  is_host  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE live_text_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_text_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ltr_select"   ON live_text_rooms FOR SELECT USING (TRUE);
CREATE POLICY "ltr_insert"   ON live_text_rooms FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "ltr_update"   ON live_text_rooms FOR UPDATE USING (auth.uid() = host_id);
CREATE POLICY "ltm_select"   ON live_text_messages FOR SELECT USING (TRUE);
CREATE POLICY "ltm_insert"   ON live_text_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ─── PROFILE HIGHLIGHTS ──────────────────────
CREATE TABLE IF NOT EXISTS profile_highlights (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  video_id    UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  title       TEXT DEFAULT 'Highlight',
  cover_url   TEXT,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, video_id)
);

ALTER TABLE profile_highlights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "hl_select" ON profile_highlights FOR SELECT USING (TRUE);
CREATE POLICY "hl_insert" ON profile_highlights FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "hl_delete" ON profile_highlights FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "hl_update" ON profile_highlights FOR UPDATE USING (auth.uid() = user_id);

-- ─── REALTIME ────────────────────────────────
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE status_posts; EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_text_rooms; EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_text_messages; EXCEPTION WHEN duplicate_object THEN NULL; END$$;

-- ─── VERIFY ──────────────────────────────────
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('status_posts','status_views','live_text_rooms','live_text_messages','profile_highlights')
ORDER BY table_name;
