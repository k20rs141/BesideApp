import Foundation
import Supabase

enum RoomError: LocalizedError {
    case notFound
    case notAuthenticated
    case ownRoom
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "コードが正しくありません"
        case .notAuthenticated:
            return "サインインが必要です"
        case .ownRoom:
            return "これはあなた自身のルームです"
        case .unknown(let err):
            return err.localizedDescription
        }
    }
}

final class RoomService {
    private let client = SupabaseManager.shared.client

    // MARK: - fetchMyRoom

    /// 自分のマイルームを返す。my_room_id 未設定の場合は ensure_my_room() RPC で作成する。
    func fetchMyRoom() async throws -> Room {
        guard let userId = try? await client.auth.session.user.id else {
            throw RoomError.notAuthenticated
        }

        // プロフィールから my_room_id を取得
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        if let myRoomId = profiles.first?.myRoomId {
            let rooms: [Room] = try await client
                .from("rooms")
                .select()
                .eq("id", value: myRoomId)
                .limit(1)
                .execute()
                .value
            if let room = rooms.first {
                return room
            }
        }

        // my_room_id 未設定 (既存ユーザーなど) → RPC で作成・設定
        let room: Room = try await client
            .rpc("ensure_my_room")
            .execute()
            .value
        return room
    }

    // MARK: - joinRoom

    /// 他ユーザーのルームにコードで参加する。自分のコードはエラー。
    func joinRoom(code: String) async throws -> Room {
        guard let userId = try? await client.auth.session.user.id else {
            throw RoomError.notAuthenticated
        }

        let rooms: [Room] = try await client
            .from("rooms")
            .select()
            .eq("code", value: code.uppercased())
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value

        guard let room = rooms.first else {
            throw RoomError.notFound
        }

        // 自分のマイルームのコードを入力した場合
        if room.hostId == userId.uuidString {
            throw RoomError.ownRoom
        }

        // 既に参加済みの場合は重複を無視して upsert
        try await client
            .from("room_participants")
            .upsert(
                ["room_id": room.id, "user_id": userId.uuidString],
                onConflict: "room_id,user_id",
                ignoreDuplicates: true
            )
            .execute()

        return room
    }

    // MARK: - leaveRoom

    /// ホスト(マイルーム)退出: ルームは永続化するため DB 変更なし。
    /// ゲスト退出: room_participants.left_at を更新。
    func leaveRoom(roomId: String, isHost: Bool) async throws {
        if isHost {
            // マイルームは永続 — ホームに戻るだけで DB は触らない
            return
        }

        guard let userId = try? await client.auth.session.user.id else {
            throw RoomError.notAuthenticated
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try await client
            .from("room_participants")
            .update(["left_at": iso.string(from: Date())])
            .eq("room_id", value: roomId)
            .eq("user_id", value: userId.uuidString)
            .is("left_at", value: nil)
            .execute()
    }
}
