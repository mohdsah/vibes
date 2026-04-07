-- ================================================================
--  VIBES v12 — Migration Fix
--  Run ini dalam Supabase SQL Editor untuk projek sedia ada
--  (Jika projek baru, run vibes_setup.sql + supabase_v11.sql dulu)
-- ================================================================

-- ── 1. live_rooms — tambah started_at ────────────────────────────
ALTER TABLE live_rooms
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ DEFAULT NOW();

-- Populate started_at dari created_at untuk rows lama
UPDATE live_rooms SET started_at = created_at WHERE started_at IS NULL;

-- ── 2. dm_messages — tambah image_url ────────────────────────────
ALTER TABLE dm_messages
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- ── 3. profiles — tambah total_coins_spent (reference column) ────
-- (total_coins_spent ada dalam user_coins, tapi admin guna profiles.*
--  untuk display — tambah shortcut column)
-- NOTE: Ini optional, admin query guna JOIN dengan user_coins

-- ── 4. live_text_rooms — tambah started_at ───────────────────────
ALTER TABLE live_text_rooms
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ DEFAULT NOW();

UPDATE live_text_rooms SET started_at = created_at WHERE started_at IS NULL;

-- ── 5. status_posts — tambah index pada user + expires ───────────
CREATE INDEX IF NOT EXISTS idx_status_user_expires
  ON status_posts(user_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_status_expires_active
  ON status_posts(expires_at DESC) WHERE expires_at > NOW();

-- ── 6. notifications — tambah entity_type indexes ─────────────────
CREATE INDEX IF NOT EXISTS idx_notif_user_unread
  ON notifications(user_id, is_read, created_at DESC);

-- ── 7. live_text_messages — tambah index ─────────────────────────
CREATE INDEX IF NOT EXISTS idx_ltm_room_created
  ON live_text_messages(room_id, created_at);

-- ── 8. topup_requests — update status check (tambah 'approved') ──
-- Already correct, just verify
-- status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected'))

-- ── 9. RLS untuk dm_messages (image_url) — update policy ─────────
-- Existing policies cover new column automatically

-- ── 10. Storage bucket untuk DM images ───────────────────────────
-- DM images guna bucket 'avatars' (path: dm/{user_id}/{filename})
-- Bucket 'avatars' sudah ada, cuma perlu update policy kalau belum
DO $$ BEGIN
  CREATE POLICY "Auth upload dm images" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id = 'avatars'
      AND auth.role() = 'authenticated'
      AND (storage.foldername(name))[1] IN ('dm', 'avatars', 'status', 'receipts')
    );
  EXCEPTION WHEN duplicate_object THEN NULL;
END$$;

-- ── 11. RLS status_views — allow viewer to select own views ───────
DROP POLICY IF EXISTS "status_views_select" ON status_views;
CREATE POLICY "status_views_select" ON status_views
  FOR SELECT USING (
    viewer_id = auth.uid()
    OR status_id IN (SELECT id FROM status_posts WHERE user_id = auth.uid())
  );

-- ── 12. Auto-cleanup expired status posts (function) ─────────────
CREATE OR REPLACE FUNCTION cleanup_expired_status()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM status_views WHERE status_id IN (
    SELECT id FROM status_posts WHERE expires_at < NOW() - INTERVAL '7 days'
  );
  DELETE FROM status_posts WHERE expires_at < NOW() - INTERVAL '7 days';
END;$$;

-- ── 13. claim_watch_reward — update in main setup ────────────────
-- Ensure function exists (idempotent)
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
  SELECT user_id INTO v_owner FROM videos WHERE id = p_video_id;
  IF v_owner = p_user_id THEN
    RETURN json_build_object('success',false,'message','owner');
  END IF;

  SELECT COUNT(*) INTO v_today_count
  FROM video_watch_rewards
  WHERE user_id=p_user_id AND reward_date=CURRENT_DATE;

  IF v_today_count >= p_daily_limit THEN
    RETURN json_build_object('success',false,'message','limit','count',v_today_count);
  END IF;

  INSERT INTO video_watch_rewards(user_id,video_id,coins_earned)
  VALUES(p_user_id,p_video_id,p_coins)
  ON CONFLICT(user_id,video_id,reward_date) DO NOTHING;

  IF NOT FOUND THEN
    RETURN json_build_object('success',false,'message','already_earned');
  END IF;

  INSERT INTO user_coins(user_id,coins,total_earned)
  VALUES(p_user_id,p_coins,p_coins)
  ON CONFLICT(user_id) DO UPDATE
  SET coins=user_coins.coins+p_coins,
      total_earned=user_coins.total_earned+p_coins,
      updated_at=NOW();

  SELECT coins INTO v_balance FROM user_coins WHERE user_id=p_user_id;
  RETURN json_build_object('success',true,'coins',p_coins,'balance',v_balance,'today',v_today_count+1,'message','earned');
END;$$;

-- ── 14. get_or_create_conversation — fix param names ─────────────
-- Profile.html calls: get_or_create_conversation(p_user1, p_user2)
-- Check current function signature and recreate with correct params
CREATE OR REPLACE FUNCTION get_or_create_conversation(
  p_user1 UUID,
  p_user2 UUID
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_conv_id UUID;
BEGIN
  -- Check existing conversation (either direction)
  SELECT id INTO v_conv_id
  FROM dm_conversations
  WHERE (user1_id = p_user1 AND user2_id = p_user2)
     OR (user1_id = p_user2 AND user2_id = p_user1)
  LIMIT 1;

  -- Create if not exists
  IF v_conv_id IS NULL THEN
    INSERT INTO dm_conversations(user1_id, user2_id)
    VALUES(p_user1, p_user2)
    RETURNING id INTO v_conv_id;
  END IF;

  RETURN v_conv_id;
END;$$;

-- ── 15. Realtime untuk new tables ────────────────────────────────
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE dm_messages;      EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_text_rooms;   EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE live_text_messages;EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE status_posts;      EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE topup_requests;    EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE withdraw_requests; EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE notifications;     EXCEPTION WHEN duplicate_object THEN NULL; END$$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE user_coins;        EXCEPTION WHEN duplicate_object THEN NULL; END$$;

-- ── 16. Cleanup stale live rooms (run jika ada orphan rooms) ──────
UPDATE live_rooms
SET status = 'ended', ended_at = NOW()
WHERE status = 'live'
  AND started_at < NOW() - INTERVAL '8 hours';

UPDATE live_text_rooms
SET status = 'ended', ended_at = NOW()
WHERE status = 'live'
  AND started_at < NOW() - INTERVAL '8 hours';

-- ── 17. Coin packages default data (kalau kosong) ─────────────────
INSERT INTO coin_packages (name, coins, price_myr, bonus_coins, is_popular, is_active)
SELECT * FROM (VALUES
  ('Starter',   100,   3.00,    0, false, true),
  ('Basic',     300,   8.00,   20, false, true),
  ('Popular',   600,  15.00,   60,  true, true),
  ('Super',    1200,  28.00,  200, false, true),
  ('Mega',     3000,  65.00,  600, false, true),
  ('Ultra',    6000, 120.00, 1500, false, true)
) AS new_pkgs(name, coins, price_myr, bonus_coins, is_popular, is_active)
WHERE NOT EXISTS (SELECT 1 FROM coin_packages LIMIT 1);

-- ── 18. Gift types default (kalau kosong) ─────────────────────────
INSERT INTO gift_types (name, emoji, coin_cost, is_active)
SELECT * FROM (VALUES
  ('Rose',         '🌹',    10, true),
  ('Heart',        '❤️',    50, true),
  ('Star',         '⭐',   100, true),
  ('Fire',         '🔥',   200, true),
  ('Diamond',      '💎',   500, true),
  ('Crown',        '👑',  1000, true),
  ('Sports Car',   '🏎️', 2000, true),
  ('Rocket',       '🚀',  5000, true)
) AS gt(name, emoji, coin_cost, is_active)
WHERE NOT EXISTS (SELECT 1 FROM gift_types LIMIT 1);

-- ── VERIFY ───────────────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM profiles)           AS users,
  (SELECT COUNT(*) FROM videos)             AS videos,
  (SELECT COUNT(*) FROM coin_packages)      AS packages,
  (SELECT COUNT(*) FROM gift_types)         AS gift_types,
  (SELECT COUNT(*) FROM status_posts)       AS status_posts,
  (SELECT COUNT(*) FROM live_text_rooms)    AS text_rooms,
  (SELECT COUNT(*) FROM profile_highlights) AS highlights;
