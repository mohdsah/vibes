-- =============================================
-- VIBES — Watch to Earn (Tonton dapat Coin)
-- Run dalam Supabase SQL Editor (projek sedia ada)
-- =============================================

-- Table: jejak reward yang dah diberi
CREATE TABLE IF NOT EXISTS video_watch_rewards (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  video_id    UUID REFERENCES videos(id)   ON DELETE CASCADE NOT NULL,
  reward_date DATE DEFAULT CURRENT_DATE,
  coins_earned INT DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  -- 1 reward per video per user per hari
  UNIQUE(user_id, video_id, reward_date)
);

CREATE INDEX IF NOT EXISTS watch_rewards_user_date ON video_watch_rewards(user_id, reward_date);

ALTER TABLE video_watch_rewards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own rewards"   ON video_watch_rewards FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own rewards" ON video_watch_rewards FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Enable realtime (optional)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE video_watch_rewards;
  EXCEPTION WHEN duplicate_object THEN NULL;
END$$;

-- ─── FUNCTION: Claim watch reward (atomic) ───
-- Dipanggil dari frontend via RPC
-- Returns: { success: bool, coins: int, message: text }
CREATE OR REPLACE FUNCTION claim_watch_reward(
  p_user_id  UUID,
  p_video_id UUID,
  p_coins    INT DEFAULT 1,
  p_daily_limit INT DEFAULT 20
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_video_owner UUID;
  v_today_count INT;
  v_wallet_coins INT;
BEGIN
  -- Jangan bagi reward kepada owner video sendiri
  SELECT user_id INTO v_video_owner FROM videos WHERE id = p_video_id;
  IF v_video_owner = p_user_id THEN
    RETURN json_build_object('success', false, 'message', 'owner');
  END IF;

  -- Check had harian
  SELECT COUNT(*) INTO v_today_count
  FROM video_watch_rewards
  WHERE user_id = p_user_id AND reward_date = CURRENT_DATE;

  IF v_today_count >= p_daily_limit THEN
    RETURN json_build_object('success', false, 'message', 'limit', 'count', v_today_count);
  END IF;

  -- Cuba insert reward (ON CONFLICT = sudah pernah dapat hari ini)
  INSERT INTO video_watch_rewards(user_id, video_id, coins_earned)
  VALUES(p_user_id, p_video_id, p_coins)
  ON CONFLICT (user_id, video_id, reward_date) DO NOTHING;

  -- Kalau tiada rows inserted, sudah dapat hari ini
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'already_earned');
  END IF;

  -- Tambah coin ke wallet
  INSERT INTO user_coins(user_id, coins, total_earned)
  VALUES(p_user_id, p_coins, p_coins)
  ON CONFLICT(user_id) DO UPDATE
  SET coins        = user_coins.coins + p_coins,
      total_earned = user_coins.total_earned + p_coins,
      updated_at   = NOW();

  -- Ambil baki terkini
  SELECT coins INTO v_wallet_coins FROM user_coins WHERE user_id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'coins',   p_coins,
    'balance', v_wallet_coins,
    'today',   v_today_count + 1,
    'message', 'earned'
  );
END;
$$;

-- VERIFY
SELECT COUNT(*) AS watch_reward_rows FROM video_watch_rewards;
