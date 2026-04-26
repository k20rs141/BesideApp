import Foundation

// MARK: - Room

struct Room: Codable, Identifiable {
    let id: String
    let code: String
    let hostId: String
    var isActive: Bool
    var currentSongId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case hostId = "host_id"
        case isActive = "is_active"
        case currentSongId = "current_song_id"
        case createdAt = "created_at"
    }
}

// MARK: - Profile

struct Profile: Codable, Identifiable {
    let id: String
    var displayName: String?
    var avatarUrl: String?
    var myRoomId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case myRoomId = "my_room_id"
    }
}

// MARK: - RoomParticipant

struct RoomParticipant: Codable, Identifiable {
    let id: String
    let roomId: String
    let userId: String
    let joinedAt: Date
    var leftAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case leftAt = "left_at"
    }
}

// MARK: - PresenceUser

struct PresenceUser: Codable, Identifiable, Equatable {
    var userId: String
    var role: String        // "host" | "guest"
    var displayName: String?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case displayName = "display_name"
    }
}
