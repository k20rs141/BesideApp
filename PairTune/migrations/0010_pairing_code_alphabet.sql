-- 0010_pairing_code_alphabet.sql
-- handle_new_user() の pairing_code 生成を 32 字アルファベット
-- (A-Z から I/O を除く + 2-9) に拡張する。
--
-- 背景:
--   旧実装は md5(random()::text || ...) の hex 出力(0-9A-F)を 8 文字取り、
--   translate(...,'O0I1','') で紛らわしい文字を除いて先頭 6 字を採用していた。
--   しかし md5 hex には O / I がそもそも含まれないため、実効的に除かれていたのは
--   0 / 1 のみ。生成コードの文字集合は 23456789ABCDEF の 14 字に留まり、
--   クライアント側(CodeEntrySheet.swift)が入力許容する 32 字
--   (ABCDEFGHJKLMNPQRSTUVWXYZ23456789) と整合していなかった。
--
--   結果として、エントロピーが期待 32^6 ≈ 10.7 億 → 実 14^6 ≈ 750 万に低下し、
--   衝突確率が約 142 倍に。また G H J K L M N P Q R S T U V W X Y Z は
--   サーバー生成では絶対に出現しなかった。
--
-- 対応:
--   1..6 のループで 32 字アルファベットから 1 文字ずつ random() で取って結合する。
--   profiles / rooms の UNIQUE 制約に対する衝突再試行ロジック・SECURITY DEFINER
--   設定・search_path は維持。
--
-- 互換性:
--   既存ユーザーの pairing_code はクライアントの 32 字アルファベットの部分集合
--   なので無効化されない(O / 0 / I / 1 は元から含まれない)。本マイグレーション
--   は新規ユーザー作成時の生成ロジックだけを差し替える。

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_room_id UUID;
  new_pairing_code TEXT;
  alphabet CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i INTEGER;
BEGIN
  -- ユニークなペアリングコード生成 (6 文字、A-Z から I/O 除く + 2-9)
  -- profiles と rooms の両方で UNIQUE 制約があるため両方をチェックする。
  LOOP
    new_pairing_code := '';
    FOR i IN 1..6 LOOP
      -- random() ∈ [0, 1), * length → [0, 32), floor + 1 → {1..32}, substr は 1-indexed
      new_pairing_code := new_pairing_code ||
        substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1);
    END LOOP;

    EXIT WHEN NOT EXISTS (SELECT 1 FROM profiles WHERE pairing_code = new_pairing_code)
      AND NOT EXISTS (SELECT 1 FROM rooms WHERE pairing_code = new_pairing_code);
  END LOOP;

  -- マイルーム作成
  INSERT INTO rooms (room_type, pairing_code)
  VALUES ('my_room', new_pairing_code)
  RETURNING id INTO new_room_id;

  -- profile 作成
  INSERT INTO profiles (id, display_name, apple_user_id, pairing_code, my_room_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'User'),
    NEW.raw_user_meta_data->>'apple_user_id',
    new_pairing_code,
    new_room_id
  );

  RETURN NEW;
END;
$$;
