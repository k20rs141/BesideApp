-- 0012_add_pair_playlists.sql
-- v0.5 / v1.1: 「ふたりのプレイリスト」(中間案 A)
--
-- 仕様: docs/PairTune_Decision_Log_v0.5.md §7-4 / docs/PairTune_DB_Schema.sql Section 5
--   - DB は複数対応スキーマで将来の複数化に耐える
--   - v1.1 は pair につき 1 行のみ運用、名前固定「ふたりのプレイリスト」
--   - 解消時は pair_relationships への FK CASCADE + preserve_memories ポリシーに従う

-- pair_playlists: ペアに紐づくプレイリスト本体
CREATE TABLE IF NOT EXISTS pair_playlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id UUID NOT NULL REFERENCES pair_relationships(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'ふたりのプレイリスト',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT one_default_playlist_per_pair_v1 UNIQUE (pair_id, name)
);
CREATE INDEX IF NOT EXISTS idx_pair_playlists_pair_id ON pair_playlists(pair_id);

-- pair_playlist_items: プレイリストに入った曲
CREATE TABLE IF NOT EXISTS pair_playlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  playlist_id UUID NOT NULL REFERENCES pair_playlists(id) ON DELETE CASCADE,
  song_id TEXT NOT NULL,
  song_title TEXT NOT NULL,
  artist_name TEXT NOT NULL,
  artwork_url TEXT,
  added_by UUID NOT NULL REFERENCES profiles(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  position INTEGER NOT NULL,
  CONSTRAINT unique_song_per_playlist UNIQUE (playlist_id, song_id)
);
CREATE INDEX IF NOT EXISTS idx_pair_playlist_items_playlist_id
  ON pair_playlist_items(playlist_id);
CREATE INDEX IF NOT EXISTS idx_pair_playlist_items_position
  ON pair_playlist_items(playlist_id, position);

-- RLS
ALTER TABLE pair_playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE pair_playlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pair members can view playlists"
  ON pair_playlists FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM pair_relationships
    WHERE id = pair_playlists.pair_id
      AND (status = 'active' OR (status = 'ended' AND preserve_memories = TRUE))
      AND (user_a_id = auth.uid() OR user_b_id = auth.uid())));

CREATE POLICY "Pair members can manage playlists"
  ON pair_playlists FOR ALL
  USING (EXISTS (
    SELECT 1 FROM pair_relationships
    WHERE id = pair_playlists.pair_id
      AND status = 'active'
      AND (user_a_id = auth.uid() OR user_b_id = auth.uid())));

CREATE POLICY "Pair members can view playlist items"
  ON pair_playlist_items FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM pair_playlists pp
    JOIN pair_relationships pr ON pr.id = pp.pair_id
    WHERE pp.id = pair_playlist_items.playlist_id
      AND (pr.status = 'active' OR (pr.status = 'ended' AND pr.preserve_memories = TRUE))
      AND (pr.user_a_id = auth.uid() OR pr.user_b_id = auth.uid())));

CREATE POLICY "Pair members can manage playlist items"
  ON pair_playlist_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM pair_playlists pp
    JOIN pair_relationships pr ON pr.id = pp.pair_id
    WHERE pp.id = pair_playlist_items.playlist_id
      AND pr.status = 'active'
      AND (pr.user_a_id = auth.uid() OR pr.user_b_id = auth.uid())));

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE pair_playlists;
ALTER PUBLICATION supabase_realtime ADD TABLE pair_playlist_items;
ALTER TABLE pair_playlist_items REPLICA IDENTITY FULL;

-- 既存ペアにデフォルトプレイリストを 1 つずつ生成
INSERT INTO pair_playlists (pair_id)
SELECT id FROM pair_relationships
WHERE status = 'active'
  AND id NOT IN (SELECT pair_id FROM pair_playlists);

-- accept_pair_request() に新規ペアの自動プレイリスト生成を追記
-- 既存の関数本体を保ちつつ、末尾の RETURN 前に INSERT を入れる
CREATE OR REPLACE FUNCTION accept_pair_request(p_request_id UUID)
RETURNS UUID AS $$
DECLARE
  v_request pair_requests%ROWTYPE;
  v_user_a UUID;
  v_user_b UUID;
  v_shared_room_id UUID;
  v_pair_id UUID;
  v_existing_pair_id UUID;
BEGIN
  SELECT * INTO v_request FROM pair_requests WHERE id = p_request_id;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Request is not pending';
  END IF;

  IF v_request.expires_at < NOW() THEN
    UPDATE pair_requests SET status = 'expired' WHERE id = p_request_id;
    RAISE EXCEPTION 'Request has expired';
  END IF;

  IF v_request.requester_id < v_request.target_id THEN
    v_user_a := v_request.requester_id;
    v_user_b := v_request.target_id;
  ELSE
    v_user_a := v_request.target_id;
    v_user_b := v_request.requester_id;
  END IF;

  -- 0006: 同じカップル再ペアリングの履歴マージ用に既存 ended ペアを検索
  SELECT id INTO v_existing_pair_id
  FROM pair_relationships
  WHERE user_a_id = v_user_a AND user_b_id = v_user_b
    AND status = 'ended'
  ORDER BY paired_at DESC LIMIT 1;

  INSERT INTO rooms (room_type) VALUES ('shared_room')
  RETURNING id INTO v_shared_room_id;

  INSERT INTO pair_relationships (user_a_id, user_b_id, shared_room_id)
  VALUES (v_user_a, v_user_b, v_shared_room_id)
  RETURNING id INTO v_pair_id;

  -- 0006 由来: 旧 ended ペアの shared_room_play_history を新 pair_id に集約
  IF v_existing_pair_id IS NOT NULL THEN
    UPDATE shared_room_play_history
    SET pair_id = v_pair_id
    WHERE pair_id = v_existing_pair_id;
  END IF;

  UPDATE profiles SET active_pair_id = v_pair_id
  WHERE id IN (v_user_a, v_user_b);

  UPDATE pair_requests
  SET status = 'accepted', responded_at = NOW()
  WHERE id = p_request_id;

  -- v1.1: 新ペアに空のデフォルトプレイリストを生成
  INSERT INTO pair_playlists (pair_id) VALUES (v_pair_id)
  ON CONFLICT (pair_id, name) DO NOTHING;

  RETURN v_pair_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
