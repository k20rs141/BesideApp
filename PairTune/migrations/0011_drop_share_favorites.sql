-- 0011_drop_share_favorites.sql
-- v0.5: お気に入り共有の opt-in を廃止。♡ は能動的な意思表示なので常に共有する。
--
-- 仕様: docs/PairTune_Decision_Log_v0.5.md §7-3 / §8-1
--   - profiles.share_favorites カラムを削除
--   - profiles.share_play_history は維持(受動的に貯まる再生履歴は opt-out 可能のまま)
--   - 「Partner can view shared favorites」RLS から share_favorites 判定を撤廃
--
-- 適用順:
--   1. RLS ポリシーから share_favorites 参照を除去
--   2. カラムを DROP

-- 1. RLS の差し替え
DROP POLICY IF EXISTS "Partner can view shared favorites" ON my_room_play_history;
CREATE POLICY "Partner can view shared favorites"
  ON my_room_play_history FOR SELECT
  USING (
    is_favorited = TRUE AND
    EXISTS (
      SELECT 1 FROM pair_relationships pr
      WHERE pr.status = 'active'
        AND (
          (pr.user_a_id = my_room_play_history.user_id AND pr.user_b_id = auth.uid()) OR
          (pr.user_b_id = my_room_play_history.user_id AND pr.user_a_id = auth.uid())
        )
    )
  );

-- 2. カラム削除
ALTER TABLE profiles DROP COLUMN IF EXISTS share_favorites;
