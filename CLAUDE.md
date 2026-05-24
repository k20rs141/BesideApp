# Beside — iOS Music Sync App

## Overview

カップル・パートナー向けの音楽同期再生アプリ。Apple Music契約者同士が、
通話なしで同じ曲を同じタイミングで聴ける。詳細は docs/Beside_仕様書_v0.2.md を参照。

## Tech Stack

- iOS 26+ / SwiftUI / async/await
- Backend: Supabase (Auth + Postgres + Realtime + Edge Functions)
- Music: Apple MusicKit
- Auth: Sign in with Apple
- Architecture: MVVM + @Observable

## Critical Rules for Claude Code

### 1. デザイン実装を壊さない (最重要)

- `BesideApp/BesideApp/` 内の SwiftUI レイアウトファイルは変更禁止
  - SignInView.swift / HomeView.swift / CodeEntrySheet.swift / RoomView.swift / SearchSheet.swift
- 機能追加は ViewModel 経由のみ
- View は `@Bindable` で ViewModel を受け取り、状態を読むだけ
- 例外的に View を変更する必要がある場合は、必ず事前に確認を取る

### 2. 仕様書ファースト

- 機能の挙動・受け入れ基準は `BesideApp/docs/Beside_仕様書_v0.2.md` に従う
- 仕様書と矛盾する実装をする場合は、必ず指摘して確認を取る

### 3. データベース変更

- スキーマ変更は `BesideApp/migrations/` ディレクトリの SQL ファイルとして実装
- 直接 Supabase ダッシュボードで変更したものは migrations/ に追記
- RLS ポリシーも同じ migrations/ で管理

### 4. 機密情報

- Supabase URL / anon key は xcconfig で管理 (`Config.xcconfig`)
- `Config.xcconfig` は .gitignore 済み (`Config.example.xcconfig` をコミット)
- API キーや秘密情報をソースコードにハードコードしない

### 5. 依存追加

- 新規 Swift Package を追加する前に必ず確認
- 現時点の依存: supabase-swift のみ (M1 で追加予定)

### 6. SwiftUI Layout Pitfalls(横はみ出し)

新規 View(特に背景グローや装飾のある画面)を作るときは、以下のテンプレートに沿って書くこと。
過去に複数の Context 画面で同じ「画面幅より大きく描画される」バグを繰り返しているため必読。

**症状**: 実機/シミュレータで右端が見切れる、または横方向にスクロールしてしまう。
ビルドや SwiftUI Preview では気づきにくい。

**原因**:
- `.frame(width: 600)` 等の**画面幅より大きい固定 width** を ZStack/VStack/HStack の子に直接置くと、
  親の layout box がその値まで広がり、兄弟の content も右側へ押し出される
- ambient glow / radial gradient のような装飾を画面より大きく描いて視覚的にブリードさせる手法は
  jsx でよく使われるが、SwiftUI の `.frame` は ideal size を申告するので副作用が大きい
- `ScrollView(.vertical)` は content の horizontal 幅を自動的には制約しない

**回避テンプレ**:
```swift
var body: some View {
    ZStack {
        Color.pairtuneBase.ignoresSafeArea()

        // 装飾は Color.clear.overlay で包む(親サイズに固定、内部は overlay の bounds で clip)
        Color.clear
            .overlay {
                Ellipse()
                    .fill(...)
                    .frame(width: 600, height: 380)   // ← 画面より大きくても OK
                    .blur(radius: 60)
                    .offset(y: -240)
                    .allowsHitTesting(false)
            }
            .clipped()
            .ignoresSafeArea()

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 中身
            }
            .frame(maxWidth: .infinity, alignment: .leading)   // ← 必須
            .padding(.bottom, 60)
        }
        .clipped()   // ← 念のため
    }
    .clipped()   // ← 念のため
}
```

**チェックリスト**(新規 View レビュー時):
- [ ] 装飾(glow / radial gradient)は `Color.clear.overlay { ... }` で包んでいるか
- [ ] ScrollView 内の root VStack に `.frame(maxWidth: .infinity, alignment: .leading)` があるか
- [ ] 外側 ZStack / ScrollView に `.clipped()` があるか
- [ ] 横スクロール ScrollView(.horizontal) も `.frame(maxWidth: .infinity)` で外形を固定しているか
- [ ] 長い Text には `.fixedSize(horizontal: false, vertical: true)` で wrap を保証しているか
- [ ] 390pt 幅のシミュレータで実機確認したか

**過去にハマった画面**: HomeView, SoloContextView, SharedContextView, AllSessionsView,
SessionDetailView, PairPlaylistDetailView。同じパターンを別の画面で再発させないこと。

## File Structure

```
BesideApp/                         ← Xcode project root
├── BesideApp/                     ← app target
│   ├── Theme.swift                デザイントークン (色・タイポグラフィ定数)
│   ├── Models.swift               データモデル + モックデータ (Track, Participant, SyncState)
│   ├── BesideAppApp.swift         アプリエントリポイント
│   ├── ContentView.swift          ルートナビゲーション (AppScreen ステートマシン)
│   ├── BesideLogoView.swift       ロゴ・ワードマークコンポーネント
│   ├── SharedComponents.swift     共通 UI (SpinnerView, SyncBadgeView, AvatarView, etc.)
│   ├── SignInView.swift            サインイン画面 ← レイアウト変更禁止
│   ├── HomeView.swift             ホーム画面 ← レイアウト変更禁止
│   ├── CodeEntrySheet.swift       コード入力シート ← レイアウト変更禁止
│   ├── RoomView.swift             ルーム画面 ← レイアウト変更禁止
│   ├── SearchSheet.swift          曲検索シート ← レイアウト変更禁止
│   ├── ViewModels/                @Observable クラス (M1以降追加)
│   ├── Services/                  SupabaseManager, MusicPlayerService等 (M1以降追加)
│   └── Extensions/                既存型の拡張 (必要に応じて追加)
├── docs/
│   ├── Beside_仕様書_v0.2.md
│   └── Beside_実装ガイド_v0.2.md
├── migrations/                    Supabase 用 SQL マイグレーション (M2以降追加)
├── Config.example.xcconfig        Supabase 接続情報テンプレート (コミット可)
└── Config.xcconfig                Supabase 接続情報 実値 (gitignore 済み・各自作成)
```

## Naming Conventions

- 型: PascalCase (`RoomView`, `SyncManager`)
- 変数・関数: camelCase
- ファイル名: 型名と一致 (`RoomView.swift`)
- ViewModel: `<Screen>ViewModel.swift`

## Build & Test Commands

```bash
# Build (simulator)
xcodebuild -scheme BesideApp -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test (将来)
xcodebuild test -scheme BesideApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Don't Do

- 装飾用の `Ellipse()` / `Rectangle()` 等を `.frame(width: 画面幅より大きい値)` で
  ZStack の子に**直接**置く(→ §6 の Color.clear.overlay パターンで包む)
- `ScrollView(.vertical)` の content VStack に `.frame(maxWidth: .infinity)` を付け忘れる
- ビルドが通っただけで「OK」と判断する(右はみ出しは Preview/ビルドでは気づけない、
  必ず 390pt 幅シミュレータで実機確認)
- エラーハンドリング UI の先行実装 (M6 でまとめて行う)
- 仕様書にない機能の追加実装
- `DispatchQueue.main.async` の使用 → `async/await + @MainActor` で書く
- API キー・秘密情報をソースコードに直書き
