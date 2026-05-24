import Foundation
import Supabase

// MARK: - PairPlaylistService (v1.1)
//
// 仕様: docs/PairTune_DB_Schema.sql Section 5 / docs/PairTune_Decision_Log_v0.5.md §7-4
// マイグレーション: PairTune/migrations/0012_add_pair_playlists.sql
//
// v1.1 は中間案 A: 1 ペアにつき 1 つだけ運用(name 固定「ふたりのプレイリスト」)。
// 複数化は v1.2 で UI 解放(スキーマ変更不要)。
//
// RLS: ペア当事者(active or ended+preserve_memories)のみ閲覧、active のみ管理可能。

// MARK: - DB Models

/// pair_playlists テーブルの 1 行
struct PairPlaylist: Codable, Identifiable {
    let id: String
    let pairId: String
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairId = "pair_id"
        case name
        case createdAt = "created_at"
    }
}

/// pair_playlist_items テーブルの 1 行
struct PairPlaylistItem: Codable, Identifiable {
    let id: String
    let playlistId: String
    let songId: String
    let songTitle: String
    let artistName: String
    let artworkUrl: String?
    let addedBy: String
    let addedAt: Date
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case playlistId = "playlist_id"
        case songId = "song_id"
        case songTitle = "song_title"
        case artistName = "artist_name"
        case artworkUrl = "artwork_url"
        case addedBy = "added_by"
        case addedAt = "added_at"
        case position
    }
}

// MARK: - Service

final class PairPlaylistService {
    private let client = SupabaseManager.shared.client

    /// このペアのデフォルトプレイリストを取得(v1.1 は 1 ペア 1 件のみ)。
    /// 0012 マイグレーションで accept_pair_request() が自動 seed するため、active ペアでは必ず 1 件存在する想定。
    /// 念のため見つからなければ INSERT してフォールバック。
    func fetchOrCreatePlaylist(pairId: String) async -> PairPlaylist? {
        do {
            let existing: [PairPlaylist] = try await client
                .from("pair_playlists")
                .select()
                .eq("pair_id", value: pairId)
                .limit(1)
                .execute()
                .value
            if let first = existing.first { return first }
        } catch {
            print("[PairPlaylistService] fetch error:", error)
        }

        struct Insert: Encodable { let pair_id: String }
        do {
            let created: [PairPlaylist] = try await client
                .from("pair_playlists")
                .insert(Insert(pair_id: pairId))
                .select()
                .execute()
                .value
            return created.first
        } catch {
            print("[PairPlaylistService] create error:", error)
            return nil
        }
    }

    /// プレイリストに含まれる曲一覧。position 昇順。
    func fetchItems(playlistId: String) async -> [PairPlaylistItem] {
        do {
            let items: [PairPlaylistItem] = try await client
                .from("pair_playlist_items")
                .select()
                .eq("playlist_id", value: playlistId)
                .order("position", ascending: true)
                .execute()
                .value
            return items
        } catch {
            print("[PairPlaylistService] fetchItems error:", error)
            return []
        }
    }

    /// 現在曲をプレイリストに追加する。重複は unique_song_per_playlist で弾かれるため、
    /// 重複エラーは「すでに追加済み」として握りつぶす(UI 上は同じトーストで OK)。
    /// 戻り値:成功=true / 失敗(重複以外)=false
    func addItem(
        playlistId: String,
        songId: String,
        songTitle: String,
        artistName: String,
        artworkUrl: String?,
        addedBy: String
    ) async -> Bool {
        // 次の position を取得(既存 items 数を末尾に積む)
        let position = await fetchItems(playlistId: playlistId).count

        struct Insert: Encodable {
            let playlist_id: String
            let song_id: String
            let song_title: String
            let artist_name: String
            let artwork_url: String?
            let added_by: String
            let position: Int
        }

        do {
            _ = try await client
                .from("pair_playlist_items")
                .insert(Insert(
                    playlist_id: playlistId,
                    song_id: songId,
                    song_title: songTitle,
                    artist_name: artistName,
                    artwork_url: artworkUrl,
                    added_by: addedBy,
                    position: position
                ))
                .execute()
            return true
        } catch {
            // unique_song_per_playlist による重複は string 比較で握りつぶす
            let message = String(describing: error).lowercased()
            if message.contains("unique") || message.contains("duplicate") {
                return true
            }
            print("[PairPlaylistService] addItem error:", error)
            return false
        }
    }

    /// アイテムを削除する(両者が自由に削除可。RLS で active ペア当事者のみ通る)
    func removeItem(itemId: String) async -> Bool {
        do {
            _ = try await client
                .from("pair_playlist_items")
                .delete()
                .eq("id", value: itemId)
                .execute()
            return true
        } catch {
            print("[PairPlaylistService] removeItem error:", error)
            return false
        }
    }
}

// MARK: - PairPlaylistItem → View 用 PairPlaylistTrack

extension PairPlaylistItem {
    /// SharedContextView の PairPlaylistTrack(View 表示用)に変換
    func toViewTrack(myUserId: String, partnerName: String? = nil) -> PairPlaylistTrack {
        let label: String
        if addedBy.lowercased() == myUserId.lowercased() {
            label = "あなた"
        } else {
            label = partnerName ?? "相手"
        }
        return PairPlaylistTrack(
            id: id,
            title: songTitle,
            artist: artistName,
            artworkUrl: artworkUrl.flatMap(URL.init(string:)),
            gradientStart: ContextSessionGrouping.gradientStart(for: songId),
            gradientEnd: ContextSessionGrouping.gradientEnd(for: songId),
            addedByLabel: label
        )
    }
}
