# Beside — iOS Music Sync App

## Overview

カップル・パートナー向けの音楽同期再生アプリ。Apple Music契約者同士が、
通話なしで同じ曲を同じタイミングで聴ける。詳細は docs/Beside_仕様書_v0.1.md を参照。

## Tech Stack

- iOS 26+ / SwiftUI / async/await
- Backend: Supabase (Auth + Postgres + Realtime + Edge Functions)
- Music: Apple MusicKit
- Auth: Sign in with Apple
- Architecture: MVVM + @Observable

## Critical Rules for Claude Code

### 1. デザイン実装を壊さない (最重要)

- Views/ ディレクトリの SwiftUI レイアウトは変更禁止
- 機能追加は ViewModel 経由のみ
- View は @Bindable で ViewModel を受け取り、状態を読むだけ
- 例外的に View を変更する必要がある場合は、必ず事前に確認を取る

### 2. 仕様書ファースト

- 機能の挙動・受け入れ基準は docs/Beside_仕様書_v0.1.md に従う
- 仕様書と矛盾する実装をする場合は、必ず指摘して確認を取る

### 3. データベース変更

- スキーマ変更は migrations/ ディレクトリの SQL ファイルとして実装
- 直接 Supabase ダッシュボードで変更したものは migrations/ に追記
- RLS ポリシーも同じ migrations/ で管理

### 4. 機密情報

- Supabase URL / anon key は xcconfig で管理 (Config.xcconfig)
- xcconfig は .gitignore 済み (Config.example.xcconfig をコミット)
- API キーや秘密情報をソースコードにハードコードしない

### 5. 依存追加

- 新規 Swift Package を追加する前に必ず確認
- 現時点の依存: supabase-swift のみ

## File Structure

- Views/                 SwiftUI 画面 (レイアウト変更禁止)
- ViewModels/            @Observable クラス
- Services/              SupabaseManager, MusicService 等の API ラッパー
- Models/                Codable struct (DTO)
- Extensions/            既存型の拡張
- migrations/            Supabase 用 SQL マイグレーション
- docs/                  仕様書・実装ガイド

## Naming Conventions

- 型: PascalCase (RoomView, SyncManager)
- 変数・関数: camelCase
- ファイル名: 型名と一致 (RoomView.swift)
- ViewModel: ViewModel.swift

## Build & Test Commands

