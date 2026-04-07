-- ================================================================
--  VIBES — COMPLETE DATABASE SETUP
--  Satu fail sahaja. Run sekali dalam Supabase SQL Editor.
--
--  Kandungan:
--    1.  Extensions
--    2.  Core tables (profiles, videos, likes, comments, follows, bookmarks)
--    3.  Comment likes + reply system
--    4.  Coin & payment tables
--    5.  Gift types (default data)
--    6.  Live streaming tables
--    7.  Social tables (DM, block, report)
--    8.  Notifications & settings
--    9.  Admin
--    10. Storage buckets
--    11. Row Level Security policies
--    12. Realtime
--    13. Functions & triggers
--    14. Immediate fixes (end stuck rooms)
--    15. Make yourself admin (uncomment & edit)
--    16. Verify query
-- ================================================================

-- ================================================================
-- 1. EXTENSIONS
-- ================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- 2. CORE TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS profiles (
  id                UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username          TEXT UNIQUE NOT NULL,
  display_name      TEXT,
  bio               TEXT,
  avatar_url        TEXT,
  followers_count   INT DEFAULT 0,
  following_count   INT DEFAULT 0,
  videos_count      INT DEFAULT 0,
  subscribers_count INT DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS videos (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id        UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title          TEXT,
  description    TEXT,
  video_url      TEXT NOT NULL,
  thumbnail_url  TEXT,
  likes_count    INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  views_count    INT DEFAULT 0,
  duration       INT DEFAULT 0,
  is_public      BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS likes (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  video_id   UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, video_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id        UUID REFERENCES profiles(id)  ON DELETE CASCADE NOT NULL,
  video_id       UUID REFERENCES videos(id)    ON DELETE CASCADE NOT NULL,
  parent_id      UUID REFERENCES comments(id)  ON DELETE CASCADE,          -- reply support
  content        TEXT NOT NULL,
  likes_count    INT DEFAULT 0,
  replies_count  INT DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS comments_parent_idx       ON comments(parent_id);
CREATE INDEX IF NOT EXISTS comments_video_parent_idx ON comments(video_id, parent_id, created_at);

CREATE TABLE IF NOT EXISTS follows (
  id           UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  follower_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

CREATE TABLE IF NOT EXISTS bookmarks (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  video_id   UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, video_id)
);

-- VIDEO WATCH REWARDS — tonton video dapat coin
CREATE TABLE IF NOT EXISTS video_watch_rewards (
  id           UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id      UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  video_id     UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  reward_date  DATE DEFAULT CURRENT_DATE,
  coins_earned INT DEFAULT 1,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, video_id, reward_date)  -- 1 reward per video per hari
);

CREATE INDEX IF NOT EXISTS watch_rewards_user_date ON video_watch_rewards(user_id, reward_date);

-- ================================================================
-- 3. COMMENT LIKES (for liking individual comments / replies)
-- ================================================================

CREATE TABLE IF NOT EXISTS comment_likes (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id)  ON DELETE CASCADE NOT NULL,
  comment_id UUID REFERENCES comments(id)  ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, comment_id)
);

-- ================================================================
-- 4. COIN & PAYMENT TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS user_coins (
  id                 UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id            UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  coins              INT DEFAULT 0,
  total_earned       INT DEFAULT 0,
  total_coins_spent  INT DEFAULT 0,
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coin_packages (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name        TEXT NOT NULL,
  coins       INT NOT NULL,
  price_myr   DECIMAL(10,2) NOT NULL,
  bonus_coins INT DEFAULT 0,
  is_popular  BOOLEAN DEFAULT FALSE,
  is_active   BOOLEAN DEFAULT TRUE
);

INSERT INTO coin_packages (name, coins, price_myr, bonus_coins, is_popular) VALUES
  ('Starter', 100,  5.00,   0,    false),
  ('Popular', 500,  20.00,  50,   true),
  ('Pro',     1000, 35.00,  150,  false),
  ('Super',   2500, 80.00,  500,  false),
  ('Mega',    5000, 150.00, 1500, false)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS topup_requests (
  id                 UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id            UUID REFERENCES profiles(id)      ON DELETE CASCADE NOT NULL,
  package_id         UUID REFERENCES coin_packages(id),
  coins_amount       INT NOT NULL,
  price_myr          DECIMAL(10,2) NOT NULL,
  payment_method     TEXT DEFAULT 'manual',
  payment_reference  TEXT,
  status             TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  receipt_url        TEXT,
  admin_note         TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  processed_at       TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS withdraw_requests (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  coins_amount  INT NOT NULL,
  rate_per_coin DECIMAL(10,4) DEFAULT 0.04,
  amount_myr    DECIMAL(10,2) NOT NULL,
  bank_name     TEXT NOT NULL,
  bank_account  TEXT NOT NULL,
  account_name  TEXT NOT NULL,
  status        TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','paid')),
  admin_note    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  processed_at  TIMESTAMPTZ
);

-- ================================================================
-- 5. GIFT TYPES (default data)
-- ================================================================

CREATE TABLE IF NOT EXISTS gift_types (
  id        UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name      TEXT NOT NULL,
  emoji     TEXT NOT NULL,
  coin_cost INT NOT NULL,
  animation TEXT DEFAULT 'float',
  color     TEXT DEFAULT '#ff2d55',
  is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO gift_types (name, emoji, coin_cost, animation, color) VALUES
  ('Rose',    '🌹', 5,    'float',   '#ff2d55'),
  ('Heart',   '❤️', 10,  'pulse',   '#ff6b6b'),
  ('Star',    '⭐', 20,  'spin',    '#ffd700'),
  ('Diamond', '💎', 50,  'sparkle', '#00d4ff'),
  ('Crown',   '👑', 100, 'bounce',  '#ffd700'),
  ('Rocket',  '🚀', 200, 'launch',  '#ff6b35'),
  ('Dragon',  '🐉', 500, 'roar',    '#a855f7'),
  ('Galaxy',  '🌌', 1000,'explode', '#6366f1')
ON CONFLICT DO NOTHING;

-- ================================================================
-- 6. LIVE STREAMING TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS live_rooms (
  id                   UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  host_id              UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title                TEXT NOT NULL,
  viewer_count         INT DEFAULT 0,
  total_coins_earned   INT DEFAULT 0,
  status               TEXT DEFAULT 'live' CHECK (status IN ('live','ended')),
  started_at           TIMESTAMPTZ DEFAULT NOW(),
  ended_at             TIMESTAMPTZ,
  thumbnail_url        TEXT,
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS live_gifts (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id       UUID REFERENCES live_rooms(id)  ON DELETE CASCADE NOT NULL,
  sender_id     UUID REFERENCES profiles(id)    ON DELETE CASCADE NOT NULL,
  receiver_id   UUID REFERENCES profiles(id)    ON DELETE CASCADE NOT NULL,
  gift_type_id  UUID REFERENCES gift_types(id)  NOT NULL,
  coin_amount   INT NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS live_chats (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id    UUID REFERENCES live_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES profiles(id)   ON DELETE CASCADE NOT NULL,
  message    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS webrtc_signals (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id    UUID REFERENCES live_rooms(id) ON DELETE CASCADE NOT NULL,
  from_user  UUID NOT NULL,
  to_user    UUID,
  type       TEXT NOT NULL CHECK (type IN ('offer','answer','ice-candidate','join','leave')),
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS gift_targets (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id        UUID REFERENCES live_rooms(id) ON DELETE CASCADE NOT NULL,
  host_id        UUID REFERENCES profiles(id)   ON DELETE CASCADE NOT NULL,
  title          TEXT NOT NULL DEFAULT 'Target Gift',
  target_coins   INT NOT NULL DEFAULT 1000,
  current_coins  INT DEFAULT 0,
  is_completed   BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  subscriber_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  creator_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(subscriber_id, creator_id)
);

-- ================================================================
-- 7. SOCIAL — DM, BLOCK, REPORT
-- ================================================================

CREATE TABLE IF NOT EXISTS dm_conversations (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user1_id         UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  user2_id         UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  last_message     TEXT,
  last_message_at  TIMESTAMPTZ DEFAULT NOW(),
  user1_unread     INT DEFAULT 0,
  user2_unread     INT DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

CREATE TABLE IF NOT EXISTS dm_messages (
  id               UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  conversation_id  UUID REFERENCES dm_conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id        UUID REFERENCES profiles(id)          ON DELETE CASCADE NOT NULL,
  content          TEXT NOT NULL,
  image_url        TEXT,
  is_read          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS blocked_users (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  reporter_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  reported_user_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reported_video_id UUID REFERENCES videos(id)   ON DELETE SET NULL,
  reason            TEXT NOT NULL CHECK (reason IN (
                      'spam','nudity','violence','hate_speech',
                      'harassment','misinformation','copyright','other')),
  description       TEXT,
  status            TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed','actioned')),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- 8. NOTIFICATIONS & USER SETTINGS
-- ================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  actor_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN (
                'like','comment','follow','subscribe','gift','live_start',
                'topup_approved','topup_rejected',
                'withdraw_approved','withdraw_rejected')),
  entity_id   UUID,
  entity_type TEXT,
  message     TEXT NOT NULL,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notif_user_idx ON notifications(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id             UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
  is_private          BOOLEAN DEFAULT FALSE,
  allow_dm_from       TEXT DEFAULT 'everyone' CHECK (allow_dm_from IN ('everyone','following','nobody')),
  show_online_status  BOOLEAN DEFAULT TRUE,
  allow_comments      TEXT DEFAULT 'everyone' CHECK (allow_comments IN ('everyone','following','nobody')),
  allow_duet          BOOLEAN DEFAULT TRUE,
  notify_like         BOOLEAN DEFAULT TRUE,
  notify_comment      BOOLEAN DEFAULT TRUE,
  notify_follow       BOOLEAN DEFAULT TRUE,
  notify_gift         BOOLEAN DEFAULT TRUE,
  notify_dm           BOOLEAN DEFAULT TRUE,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS video_analytics (
  id             UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  video_id       UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  user_id        UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  date           DATE DEFAULT CURRENT_DATE,
  views_delta    INT DEFAULT 0,
  likes_delta    INT DEFAULT 0,
  comments_delta INT DEFAULT 0,
  shares_delta   INT DEFAULT 0,
  UNIQUE(video_id, date)
);

-- ================================================================
-- 9. ADMIN
-- ================================================================

CREATE TABLE IF NOT EXISTS admin_users (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  role       TEXT DEFAULT 'admin' CHECK (role IN ('admin','superadmin')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- 10. STORAGE BUCKETS
-- ================================================================

INSERT INTO storage.buckets (id, name, public) VALUES ('videos',     'videos',     TRUE) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('thumbnails', 'thumbnails', TRUE) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars',    'avatars',    TRUE) ON CONFLICT DO NOTHING;

DO $$ BEGIN CREATE POLICY "Public videos bucket"         ON storage.objects FOR SELECT USING (bucket_id='videos'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Auth upload videos"           ON storage.objects FOR INSERT WITH CHECK (bucket_id='videos' AND auth.role()='authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Public thumbnails bucket"     ON storage.objects FOR SELECT USING (bucket_id='thumbnails'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Auth upload thumbnails"       ON storage.objects FOR INSERT WITH CHECK (bucket_id='thumbnails' AND auth.role()='authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Public avatars bucket"        ON storage.objects FOR SELECT USING (bucket_id='avatars'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Auth upload avatars"          ON storage.objects FOR INSERT WITH CHECK (bucket_id='avatars' AND auth.role()='authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN CREATE POLICY "Auth update avatars"          ON storage.objects FOR UPDATE USING (bucket_id='avatars' AND auth.uid()::text=(storage.foldername(name))[1]); EXCEPTION WHEN duplicate_object THEN NULL; END$$;

-- ================================================================
-- 11. ROW LEVEL SECURITY
-- ================================================================

ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows           ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_watch_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_coins        ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_packages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE topup_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdraw_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_types        ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_rooms        ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_gifts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_chats        ENABLE ROW LEVEL SECURITY;
ALTER TABLE webrtc_signals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_targets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE dm_conversations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE dm_messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports           ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_analytics   ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users       ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles_select"   ON profiles FOR SELECT USING (TRUE);
CREATE POLICY "profiles_insert"   ON profiles FOR INSERT WITH CHECK (auth.uid()=id);
CREATE POLICY "profiles_update"   ON profiles FOR UPDATE USING (auth.uid()=id);

-- videos
CREATE POLICY "videos_select"     ON videos FOR SELECT USING (is_public=TRUE OR auth.uid()=user_id);
CREATE POLICY "videos_insert"     ON videos FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "videos_update"     ON videos FOR UPDATE USING (auth.uid()=user_id);
CREATE POLICY "videos_delete"     ON videos FOR DELETE USING (auth.uid()=user_id);

-- likes
CREATE POLICY "likes_select"      ON likes FOR SELECT USING (TRUE);
CREATE POLICY "likes_insert"      ON likes FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "likes_delete"      ON likes FOR DELETE USING (auth.uid()=user_id);

-- comments
CREATE POLICY "comments_select"   ON comments FOR SELECT USING (TRUE);
CREATE POLICY "comments_insert"   ON comments FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "comments_delete"   ON comments FOR DELETE USING (auth.uid()=user_id);

-- comment_likes
CREATE POLICY "clikes_select"     ON comment_likes FOR SELECT USING (TRUE);
CREATE POLICY "clikes_insert"     ON comment_likes FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "clikes_delete"     ON comment_likes FOR DELETE USING (auth.uid()=user_id);

-- follows
CREATE POLICY "follows_select"    ON follows FOR SELECT USING (TRUE);
CREATE POLICY "follows_insert"    ON follows FOR INSERT WITH CHECK (auth.uid()=follower_id);
CREATE POLICY "follows_delete"    ON follows FOR DELETE USING (auth.uid()=follower_id);

-- bookmarks
CREATE POLICY "bookmarks_select"  ON bookmarks FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "bookmarks_insert"  ON bookmarks FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "bookmarks_delete"  ON bookmarks FOR DELETE USING (auth.uid()=user_id);

-- video_watch_rewards
CREATE POLICY "rewards_select"    ON video_watch_rewards FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "rewards_insert"    ON video_watch_rewards FOR INSERT WITH CHECK (auth.uid()=user_id);

-- user_coins
CREATE POLICY "coins_select"      ON user_coins FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "coins_insert"      ON user_coins FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "coins_update"      ON user_coins FOR UPDATE USING (auth.uid()=user_id);

-- coin_packages (public read)
CREATE POLICY "packages_select"   ON coin_packages FOR SELECT USING (is_active=TRUE);

-- topup_requests
CREATE POLICY "topup_select"      ON topup_requests FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "topup_insert"      ON topup_requests FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "topup_update"      ON topup_requests FOR UPDATE USING (TRUE);

-- withdraw_requests
CREATE POLICY "withdraw_select"   ON withdraw_requests FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "withdraw_insert"   ON withdraw_requests FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "withdraw_update"   ON withdraw_requests FOR UPDATE USING (TRUE);

-- gift_types (public read)
CREATE POLICY "gifts_select"      ON gift_types FOR SELECT USING (is_active=TRUE);

-- live_rooms
CREATE POLICY "rooms_select"      ON live_rooms FOR SELECT USING (TRUE);
CREATE POLICY "rooms_insert"      ON live_rooms FOR INSERT WITH CHECK (auth.uid()=host_id);
CREATE POLICY "rooms_update"      ON live_rooms FOR UPDATE USING (auth.uid()=host_id);

-- live_gifts
CREATE POLICY "lgifts_select"     ON live_gifts FOR SELECT USING (TRUE);
CREATE POLICY "lgifts_insert"     ON live_gifts FOR INSERT WITH CHECK (auth.uid()=sender_id);

-- live_chats
CREATE POLICY "lchats_select"     ON live_chats FOR SELECT USING (TRUE);
CREATE POLICY "lchats_insert"     ON live_chats FOR INSERT WITH CHECK (auth.uid()=user_id);

-- webrtc_signals
CREATE POLICY "signals_select"    ON webrtc_signals FOR SELECT USING (TRUE);
CREATE POLICY "signals_insert"    ON webrtc_signals FOR INSERT WITH CHECK (auth.uid()=from_user);

-- gift_targets
CREATE POLICY "targets_select"    ON gift_targets FOR SELECT USING (TRUE);
CREATE POLICY "targets_insert"    ON gift_targets FOR INSERT WITH CHECK (auth.uid()=host_id);
CREATE POLICY "targets_update"    ON gift_targets FOR UPDATE USING (auth.uid()=host_id);

-- subscriptions
CREATE POLICY "subs_select"       ON subscriptions FOR SELECT USING (TRUE);
CREATE POLICY "subs_insert"       ON subscriptions FOR INSERT WITH CHECK (auth.uid()=subscriber_id);
CREATE POLICY "subs_delete"       ON subscriptions FOR DELETE USING (auth.uid()=subscriber_id);

-- dm_conversations
CREATE POLICY "convos_select"     ON dm_conversations FOR SELECT USING (auth.uid()=user1_id OR auth.uid()=user2_id);
CREATE POLICY "convos_insert"     ON dm_conversations FOR INSERT WITH CHECK (auth.uid()=user1_id OR auth.uid()=user2_id);
CREATE POLICY "convos_update"     ON dm_conversations FOR UPDATE USING (auth.uid()=user1_id OR auth.uid()=user2_id);

-- dm_messages
CREATE POLICY "msgs_select"       ON dm_messages FOR SELECT USING (
  conversation_id IN (SELECT id FROM dm_conversations WHERE user1_id=auth.uid() OR user2_id=auth.uid())
);
CREATE POLICY "msgs_insert"       ON dm_messages FOR INSERT WITH CHECK (auth.uid()=sender_id);
CREATE POLICY "msgs_delete"       ON dm_messages FOR DELETE USING (auth.uid()=sender_id);

-- blocked_users
CREATE POLICY "blocks_select"     ON blocked_users FOR SELECT USING (auth.uid()=blocker_id);
CREATE POLICY "blocks_insert"     ON blocked_users FOR INSERT WITH CHECK (auth.uid()=blocker_id);
CREATE POLICY "blocks_delete"     ON blocked_users FOR DELETE USING (auth.uid()=blocker_id);

-- reports
CREATE POLICY "reports_insert"    ON reports FOR SELECT  USING (auth.uid()=reporter_id);
CREATE POLICY "reports_select"    ON reports FOR INSERT  WITH CHECK (auth.uid()=reporter_id);
CREATE POLICY "reports_admin_sel" ON reports FOR SELECT  USING (EXISTS(SELECT 1 FROM admin_users WHERE user_id=auth.uid()));
CREATE POLICY "reports_admin_upd" ON reports FOR UPDATE  USING (EXISTS(SELECT 1 FROM admin_users WHERE user_id=auth.uid()));

-- notifications
CREATE POLICY "notifs_select"     ON notifications FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "notifs_insert"     ON notifications FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "notifs_update"     ON notifications FOR UPDATE USING (auth.uid()=user_id);
CREATE POLICY "notifs_delete"     ON notifications FOR DELETE USING (auth.uid()=user_id);

-- user_settings
CREATE POLICY "settings_select"   ON user_settings FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "settings_insert"   ON user_settings FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "settings_update"   ON user_settings FOR UPDATE USING (auth.uid()=user_id);

-- video_analytics
CREATE POLICY "analytics_select"  ON video_analytics FOR SELECT USING (auth.uid()=user_id);
CREATE POLICY "analytics_insert"  ON video_analytics FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "analytics_update"  ON video_analytics FOR UPDATE USING (TRUE);

-- admin_users
CREATE POLICY "admins_select"     ON admin_users FOR SELECT USING (auth.uid()=user_id);

-- ================================================================
-- 12. REALTIME
-- ================================================================

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_rooms;       EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_chats;       EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_gifts;       EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE webrtc_signals;   EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE gift_targets;     EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;    EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE dm_messages;      EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE dm_conversations; EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE notifications;    EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE comment_likes;    EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE reports;          EXCEPTION WHEN duplicate_object THEN NULL; END$$;

-- ================================================================
-- 13. FUNCTIONS & TRIGGERS
-- ================================================================

-- ── Auto-create profile on signup ───────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles(id, username, display_name)
  VALUES(
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_'||substr(NEW.id::text,1,8)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'New User')
  ) ON CONFLICT(id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── Auto-create wallet on new profile ───────
CREATE OR REPLACE FUNCTION handle_new_user_coins()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_coins(user_id, coins, total_earned, total_coins_spent)
  VALUES(NEW.id, 0, 0, 0) ON CONFLICT(user_id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_profile_created_coins ON public.profiles;
CREATE TRIGGER on_profile_created_coins
  AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_new_user_coins();

-- ── Auto-create settings on new profile ─────
CREATE OR REPLACE FUNCTION handle_new_user_settings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_settings(user_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_profile_created_settings ON public.profiles;
CREATE TRIGGER on_profile_created_settings
  AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_new_user_settings();

-- ── Video likes count ────────────────────────
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE videos SET likes_count=likes_count+1 WHERE id=NEW.video_id;
  ELSIF TG_OP='DELETE' THEN UPDATE videos SET likes_count=GREATEST(0,likes_count-1) WHERE id=OLD.video_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_like_change ON likes;
CREATE TRIGGER on_like_change AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION update_likes_count();

-- ── Video comments count ─────────────────────
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE videos SET comments_count=comments_count+1 WHERE id=NEW.video_id;
  ELSIF TG_OP='DELETE' THEN UPDATE videos SET comments_count=GREATEST(0,comments_count-1) WHERE id=OLD.video_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_comment_change ON comments;
CREATE TRIGGER on_comment_change AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_comments_count();

-- ── Comment likes count ──────────────────────
CREATE OR REPLACE FUNCTION update_comment_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE comments SET likes_count=likes_count+1 WHERE id=NEW.comment_id;
  ELSIF TG_OP='DELETE' THEN UPDATE comments SET likes_count=GREATEST(0,likes_count-1) WHERE id=OLD.comment_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_comment_like_change ON comment_likes;
CREATE TRIGGER on_comment_like_change AFTER INSERT OR DELETE ON comment_likes
  FOR EACH ROW EXECUTE FUNCTION update_comment_likes_count();

-- ── Comment replies count ────────────────────
CREATE OR REPLACE FUNCTION update_replies_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' AND NEW.parent_id IS NOT NULL THEN
    UPDATE comments SET replies_count=replies_count+1 WHERE id=NEW.parent_id;
  ELSIF TG_OP='DELETE' AND OLD.parent_id IS NOT NULL THEN
    UPDATE comments SET replies_count=GREATEST(0,replies_count-1) WHERE id=OLD.parent_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_reply_change ON comments;
CREATE TRIGGER on_reply_change AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_replies_count();

-- ── Videos count on profile ──────────────────
CREATE OR REPLACE FUNCTION update_video_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE profiles SET videos_count=videos_count+1 WHERE id=NEW.user_id;
  ELSIF TG_OP='DELETE' THEN UPDATE profiles SET videos_count=GREATEST(0,videos_count-1) WHERE id=OLD.user_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_video_change ON videos;
CREATE TRIGGER on_video_change AFTER INSERT OR DELETE ON videos
  FOR EACH ROW EXECUTE FUNCTION update_video_count();

-- ── Follower / following counts ──────────────
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    UPDATE profiles SET followers_count=followers_count+1 WHERE id=NEW.following_id;
    UPDATE profiles SET following_count=following_count+1 WHERE id=NEW.follower_id;
  ELSIF TG_OP='DELETE' THEN
    UPDATE profiles SET followers_count=GREATEST(0,followers_count-1) WHERE id=OLD.following_id;
    UPDATE profiles SET following_count=GREATEST(0,following_count-1) WHERE id=OLD.follower_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_follow_change ON follows;
CREATE TRIGGER on_follow_change AFTER INSERT OR DELETE ON follows
  FOR EACH ROW EXECUTE FUNCTION update_follow_counts();

-- ── Subscriber count ─────────────────────────
CREATE OR REPLACE FUNCTION update_subscriber_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP='INSERT' THEN UPDATE profiles SET subscribers_count=COALESCE(subscribers_count,0)+1 WHERE id=NEW.creator_id;
  ELSIF TG_OP='DELETE' THEN UPDATE profiles SET subscribers_count=GREATEST(0,COALESCE(subscribers_count,0)-1) WHERE id=OLD.creator_id;
  END IF; RETURN NULL;
END;$$;

DROP TRIGGER IF EXISTS on_subscription_change ON subscriptions;
CREATE TRIGGER on_subscription_change AFTER INSERT OR DELETE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_subscriber_count();

-- ── Gift: deduct coins, credit receiver, update room ─
CREATE OR REPLACE FUNCTION handle_gift_coins()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Deduct from sender
  UPDATE user_coins
  SET coins=coins-NEW.coin_amount,
      total_coins_spent=COALESCE(total_coins_spent,0)+NEW.coin_amount,
      updated_at=NOW()
  WHERE user_id=NEW.sender_id AND coins>=NEW.coin_amount;

  IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient coins'; END IF;

  -- Credit 70% to receiver (30% platform fee)
  INSERT INTO user_coins(user_id,coins,total_earned)
  VALUES(NEW.receiver_id,FLOOR(NEW.coin_amount*0.7),FLOOR(NEW.coin_amount*0.7))
  ON CONFLICT(user_id) DO UPDATE
  SET coins=user_coins.coins+FLOOR(NEW.coin_amount*0.7),
      total_earned=user_coins.total_earned+FLOOR(NEW.coin_amount*0.7),
      updated_at=NOW();

  -- Update room earnings
  UPDATE live_rooms SET total_coins_earned=total_coins_earned+NEW.coin_amount WHERE id=NEW.room_id;

  -- Update gift target progress
  UPDATE gift_targets
  SET current_coins=current_coins+NEW.coin_amount,
      is_completed=(current_coins+NEW.coin_amount>=target_coins)
  WHERE room_id=NEW.room_id AND NOT is_completed;

  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_gift_sent ON live_gifts;
CREATE TRIGGER on_gift_sent BEFORE INSERT ON live_gifts
  FOR EACH ROW EXECUTE FUNCTION handle_gift_coins();

-- ── Live room: reset viewer count on end ─────
CREATE OR REPLACE FUNCTION reset_live_room_on_end()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status='ended' AND OLD.status='live' THEN
    NEW.viewer_count:=0;
    IF NEW.ended_at IS NULL THEN NEW.ended_at:=NOW(); END IF;
  END IF; RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_live_room_end ON live_rooms;
CREATE TRIGGER on_live_room_end BEFORE UPDATE ON live_rooms
  FOR EACH ROW EXECUTE FUNCTION reset_live_room_on_end();

-- ── Topup: approved/rejected notification + credit ─
CREATE OR REPLACE FUNCTION handle_topup_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status='approved' AND OLD.status='pending' THEN
    INSERT INTO user_coins(user_id,coins) VALUES(NEW.user_id,NEW.coins_amount)
    ON CONFLICT(user_id) DO UPDATE SET coins=user_coins.coins+NEW.coins_amount,updated_at=NOW();
    INSERT INTO notifications(user_id,type,entity_id,entity_type,message)
    VALUES(NEW.user_id,'topup_approved',NEW.id,'topup','✅ Top up 💎'||NEW.coins_amount||' coins berjaya dikreditkan!');
    UPDATE topup_requests SET processed_at=NOW() WHERE id=NEW.id;
  ELSIF NEW.status='rejected' AND OLD.status='pending' THEN
    INSERT INTO notifications(user_id,type,entity_id,entity_type,message)
    VALUES(NEW.user_id,'topup_rejected',NEW.id,'topup','❌ Top up ditolak. '||COALESCE(NEW.admin_note,'Sila hubungi admin.'));
    UPDATE topup_requests SET processed_at=NOW() WHERE id=NEW.id;
  END IF; RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_topup_status ON topup_requests;
CREATE TRIGGER on_topup_status AFTER UPDATE ON topup_requests
  FOR EACH ROW EXECUTE FUNCTION handle_topup_status();

-- ── Withdraw: approved/rejected notification + deduct ─
CREATE OR REPLACE FUNCTION handle_withdraw_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status='approved' AND OLD.status='pending' THEN
    UPDATE user_coins SET coins=GREATEST(0,coins-NEW.coins_amount),updated_at=NOW() WHERE user_id=NEW.user_id;
    INSERT INTO notifications(user_id,type,entity_id,entity_type,message)
    VALUES(NEW.user_id,'withdraw_approved',NEW.id,'withdraw','Permintaan withdraw RM'||NEW.amount_myr||' diluluskan! 🎉');
    UPDATE withdraw_requests SET processed_at=NOW() WHERE id=NEW.id;
  ELSIF NEW.status='rejected' AND OLD.status='pending' THEN
    INSERT INTO notifications(user_id,type,entity_id,entity_type,message)
    VALUES(NEW.user_id,'withdraw_rejected',NEW.id,'withdraw','Permintaan withdraw ditolak. '||COALESCE(NEW.admin_note,'Sila hubungi admin.'));
    UPDATE withdraw_requests SET processed_at=NOW() WHERE id=NEW.id;
  END IF; RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_withdraw_status ON withdraw_requests;
CREATE TRIGGER on_withdraw_status AFTER UPDATE ON withdraw_requests
  FOR EACH ROW EXECUTE FUNCTION handle_withdraw_status();

-- ── Notify: like ─────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uid UUID; v_uname TEXT; v_title TEXT;
BEGIN
  SELECT user_id INTO v_uid FROM videos WHERE id=NEW.video_id;
  SELECT username INTO v_uname FROM profiles WHERE id=NEW.user_id;
  SELECT COALESCE(title,'video kau') INTO v_title FROM videos WHERE id=NEW.video_id;
  IF v_uid!=NEW.user_id THEN
    INSERT INTO notifications(user_id,actor_id,type,entity_id,entity_type,message)
    VALUES(v_uid,NEW.user_id,'like',NEW.video_id,'video',v_uname||' menyukai '||v_title);
  END IF; RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_like_notify ON likes;
CREATE TRIGGER on_like_notify AFTER INSERT ON likes
  FOR EACH ROW EXECUTE FUNCTION notify_on_like();

-- ── Notify: comment ──────────────────────────
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uid UUID; v_uname TEXT;
BEGIN
  SELECT user_id INTO v_uid FROM videos WHERE id=NEW.video_id;
  SELECT username INTO v_uname FROM profiles WHERE id=NEW.user_id;
  IF v_uid!=NEW.user_id THEN
    INSERT INTO notifications(user_id,actor_id,type,entity_id,entity_type,message)
    VALUES(v_uid,NEW.user_id,'comment',NEW.video_id,'video',v_uname||' mengomen: "'||LEFT(NEW.content,50)||'"');
  END IF; RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_comment_notify ON comments;
CREATE TRIGGER on_comment_notify AFTER INSERT ON comments
  FOR EACH ROW EXECUTE FUNCTION notify_on_comment();

-- ── Notify: follow ───────────────────────────
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uname TEXT;
BEGIN
  SELECT username INTO v_uname FROM profiles WHERE id=NEW.follower_id;
  INSERT INTO notifications(user_id,actor_id,type,entity_id,entity_type,message)
  VALUES(NEW.following_id,NEW.follower_id,'follow',NEW.follower_id,'profile',v_uname||' mula mengikuti kau');
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_follow_notify ON follows;
CREATE TRIGGER on_follow_notify AFTER INSERT ON follows
  FOR EACH ROW EXECUTE FUNCTION notify_on_follow();

-- ── Notify: subscribe ────────────────────────
CREATE OR REPLACE FUNCTION notify_on_subscribe()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uname TEXT;
BEGIN
  SELECT username INTO v_uname FROM profiles WHERE id=NEW.subscriber_id;
  INSERT INTO notifications(user_id,actor_id,type,entity_id,entity_type,message)
  VALUES(NEW.creator_id,NEW.subscriber_id,'subscribe',NEW.subscriber_id,'profile',v_uname||' 🔔 melanggan channel kau!');
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_subscribe_notify ON subscriptions;
CREATE TRIGGER on_subscribe_notify AFTER INSERT ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION notify_on_subscribe();

-- ── Notify: gift ─────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_gift()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_uname TEXT; v_gname TEXT; v_gemoji TEXT;
BEGIN
  SELECT username INTO v_uname FROM profiles WHERE id=NEW.sender_id;
  SELECT name,emoji INTO v_gname,v_gemoji FROM gift_types WHERE id=NEW.gift_type_id;
  INSERT INTO notifications(user_id,actor_id,type,entity_id,entity_type,message)
  VALUES(NEW.receiver_id,NEW.sender_id,'gift',NEW.room_id,'live',v_uname||' menghantar '||v_gname||' '||v_gemoji||' (💎 '||NEW.coin_amount||')');
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_gift_notify ON live_gifts;
CREATE TRIGGER on_gift_notify AFTER INSERT ON live_gifts
  FOR EACH ROW EXECUTE FUNCTION notify_on_gift();

-- ── DM: update conversation on new message ───
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE conv dm_conversations%ROWTYPE;
BEGIN
  SELECT * INTO conv FROM dm_conversations WHERE id=NEW.conversation_id;
  UPDATE dm_conversations SET
    last_message    = LEFT(NEW.content,100),
    last_message_at = NEW.created_at,
    user1_unread = CASE WHEN conv.user1_id!=NEW.sender_id THEN conv.user1_unread+1 ELSE conv.user1_unread END,
    user2_unread = CASE WHEN conv.user2_id!=NEW.sender_id THEN conv.user2_unread+1 ELSE conv.user2_unread END
  WHERE id=NEW.conversation_id;
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_dm_message ON dm_messages;
CREATE TRIGGER on_dm_message AFTER INSERT ON dm_messages
  FOR EACH ROW EXECUTE FUNCTION update_conversation_on_message();

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- ── Watch reward: claim (atomic, anti-abuse) ─
CREATE OR REPLACE FUNCTION claim_watch_reward(
  p_user_id     UUID,
  p_video_id    UUID,
  p_coins       INT DEFAULT 1,
  p_daily_limit INT DEFAULT 20
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner       UUID;
  v_today_count INT;
  v_balance     INT;
BEGIN
  -- Owner video tak dapat reward
  SELECT user_id INTO v_owner FROM videos WHERE id = p_video_id;
  IF v_owner = p_user_id THEN
    RETURN json_build_object('success',false,'message','owner');
  END IF;

  -- Semak had harian
  SELECT COUNT(*) INTO v_today_count
  FROM video_watch_rewards
  WHERE user_id=p_user_id AND reward_date=CURRENT_DATE;

  IF v_today_count >= p_daily_limit THEN
    RETURN json_build_object('success',false,'message','limit','count',v_today_count);
  END IF;

  -- Insert reward (UNIQUE constraint prevent duplicate)
  INSERT INTO video_watch_rewards(user_id,video_id,coins_earned)
  VALUES(p_user_id,p_video_id,p_coins)
  ON CONFLICT(user_id,video_id,reward_date) DO NOTHING;

  IF NOT FOUND THEN
    RETURN json_build_object('success',false,'message','already_earned');
  END IF;

  -- Tambah coin
  INSERT INTO user_coins(user_id,coins,total_earned)
  VALUES(p_user_id,p_coins,p_coins)
  ON CONFLICT(user_id) DO UPDATE
  SET coins=user_coins.coins+p_coins,
      total_earned=user_coins.total_earned+p_coins,
      updated_at=NOW();

  SELECT coins INTO v_balance FROM user_coins WHERE user_id=p_user_id;

  RETURN json_build_object(
    'success',true,'coins',p_coins,'balance',v_balance,
    'today',v_today_count+1,'message','earned'
  );
END;$$;

-- Get or create DM conversation (called from frontend via RPC)
-- Accept both (user_a, user_b) and (p_user1, p_user2) param names
CREATE OR REPLACE FUNCTION get_or_create_conversation(p_user1 UUID, p_user2 UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE conv_id UUID; u1 UUID; u2 UUID;
BEGIN
  -- Canonical order to avoid duplicates
  IF p_user1 < p_user2 THEN u1:=p_user1; u2:=p_user2;
  ELSE u1:=p_user2; u2:=p_user1; END IF;
  SELECT id INTO conv_id FROM dm_conversations WHERE user1_id=u1 AND user2_id=u2;
  IF conv_id IS NULL THEN
    INSERT INTO dm_conversations(user1_id,user2_id) VALUES(u1,u2) RETURNING id INTO conv_id;
  END IF;
  RETURN conv_id;
END;$$;

-- Cleanup orphaned live rooms (streams that died without proper end)
CREATE OR REPLACE FUNCTION cleanup_stale_live_rooms()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE live_rooms SET status='ended',ended_at=NOW(),viewer_count=0
  WHERE status='live' AND (updated_at < NOW()-INTERVAL '2 minutes' OR started_at < NOW()-INTERVAL '6 hours');
END;$$;

-- ================================================================
-- 14. IMMEDIATE FIXES — end all stuck live rooms NOW
-- ================================================================
UPDATE live_rooms
SET status='ended', ended_at=NOW(), viewer_count=0
WHERE status='live';

-- ================================================================
-- 15. MAKE YOURSELF ADMIN
-- Uncomment, ganti email, run sekali sahaja.
-- ================================================================
-- INSERT INTO admin_users(user_id)
-- SELECT id FROM profiles
-- WHERE id IN (SELECT id FROM auth.users WHERE email = 'EMAIL_KAU@gmail.com')
-- ON CONFLICT DO NOTHING;

-- ================================================================
-- 16. VERIFY — semak semua OK
-- ================================================================
SELECT
  (SELECT COUNT(*) FROM profiles)          AS profiles,
  (SELECT COUNT(*) FROM videos)            AS videos,
  (SELECT COUNT(*) FROM gift_types)        AS gift_types,
  (SELECT COUNT(*) FROM coin_packages)     AS coin_packages,
  (SELECT COUNT(*) FROM live_rooms)        AS live_rooms,
  (SELECT COUNT(*) FROM notifications)     AS notifications,
  (SELECT COUNT(*) FROM admin_users)       AS admins;
