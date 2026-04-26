import Foundation
import Supabase

enum RoomError: LocalizedError {
    case notFound
    case notAuthenticated
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "コードが正しくないか、ルームが終了しています"
        case .notAuthenticated:
            return "サインインが必要です"
        case .unknown(let err):
            return err.localizedDescription
        }
    }
}

final class RoomService {
    private let client = SupabaseManager.shared.client

    // MARK: - createRoom

    func createRoom() async throws -> Room {
        let room: Room = try await client
            .rpc("create_room")
            .execute()
            .value
        return room
    }

    // MARK: - fetchActiveRoom

    /// 自分が参加中（left_at IS NULL）のアクティブルームを返す。なければ nil。
    func fetchActiveRoom() async throws -> (room: Room, isHost: Bool)? {
        guard let userId = try? await client.auth.session.user.id else {
            return nil
        }

        // room_participants と rooms を JOIN して取得
        struct ParticipantWithRoom: Decodable {
            let roomId: String
            let leftAt: Date?
            let rooms: Room

            enum CodingKeys: String, CodingKey {
                case roomId = "room_id"
                case leftAt = "left_at"
                case rooms
            }
        }

        let rows: [ParticipantWithRoom] = try await client
            .from("room_participants")
            .select("room_id, left_at, rooms(*)")
            .eq("user_id", value: userId.uuidString)
            .is("left_at", value: nil)
            .eq("rooms.is_active", value: true)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first, row.rooms.isActive else {
            return nil
        }

        let isHost = row.rooms.hostId == userId.uuidString
        return (room: row.rooms, isHost: isHost)
    }

    // MARK: - joinRoom

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

        // 既に参加済みの場合は重複を無視して insert
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

    func leaveRoom(roomId: String, isHost: Bool) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw RoomError.notAuthenticated
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = iso.string(from: Date())

        // 参加者レコードに退出時刻を記録
        try await client
            .from("room_participants")
            .update(["left_at": now])
            .eq("room_id", value: roomId)
            .eq("user_id", value: userId.uuidString)
            .is("left_at", value: nil)
            .execute()

        // ホストが退出したらルームを閉じる
        if isHost {
            try await client
                .from("rooms")
                .update(["is_active": false])
                .eq("id", value: roomId)
                .execute()
        }
    }
}
