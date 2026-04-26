import SwiftUI

// MARK: - Navigation

enum AppScreen { case signIn, home, room }

// MARK: - Sync State

enum SyncState: Equatable {
    case idle, loading, playing, paused, outOfSync, disconnected

    var labelJa: String {
        switch self {
        case .idle:         return "ホスト選曲待ち"
        case .loading:      return "読み込み中"
        case .playing:      return "同期中"
        case .paused:       return "一時停止"
        case .outOfSync:    return "補正中"
        case .disconnected: return "再接続中"
        }
    }

    var labelEn: String {
        switch self {
        case .idle:         return "awaiting host"
        case .loading:      return "loading"
        case .playing:      return "in sync"
        case .paused:       return "paused"
        case .outOfSync:    return "realigning"
        case .disconnected: return "reconnecting"
        }
    }

    var color: Color {
        switch self {
        case .idle:                  return .besideTextTertiary
        case .loading, .outOfSync:  return .besideSyncWarn
        case .playing:              return .besideSyncOk
        case .paused:               return .besideTextSecondary
        case .disconnected:         return .besideSyncBad
        }
    }

    var pulses: Bool {
        switch self {
        case .loading, .outOfSync, .disconnected: return true
        default: return false
        }
    }
}

// MARK: - Track

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Int // seconds
    let gradientStops: [Gradient.Stop]
    let dominant: Color

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
}

// MARK: - Participant

enum ParticipantRole { case host, guest }

struct Participant: Identifiable {
    let id: String
    let name: String
    let nameJa: String
    let role: ParticipantRole
    let color: Color
    let initials: String
}

// MARK: - Time formatting

func fmt(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

// MARK: - Mock data

let mockTrack = Track(
    id: "t1",
    title: "Never Goodbye",
    artist: "NCT DREAM",
    album: "DREAM( )SCAPE",
    duration: 217,
    gradientStops: [
        .init(color: Color(hex: "FF5A6E"), location: 0.00),
        .init(color: Color(hex: "B83C5E"), location: 0.30),
        .init(color: Color(hex: "4A1D3D"), location: 0.70),
        .init(color: Color(hex: "1A0E1F"), location: 1.00),
    ],
    dominant: Color(hex: "FF5A6E")
)

let mockCode = "KTOMSO"

let mockParticipants: [Participant] = [
    Participant(id: "me",  name: "You", nameJa: "あなた", role: .host,  color: .besideCoral,          initials: "YO"),
    Participant(id: "aoi", name: "Aoi", nameJa: "あおい", role: .guest, color: Color(hex: "7BD389"),  initials: "AO"),
    Participant(id: "ren", name: "Ren", nameJa: "れん",   role: .guest, color: Color(hex: "6BB6F0"),  initials: "RE"),
    Participant(id: "mio", name: "Mio", nameJa: "みお",   role: .guest, color: Color(hex: "F4C26A"),  initials: "MI"),
    Participant(id: "kai", name: "Kai", nameJa: "かい",   role: .guest, color: Color(hex: "C49AF4"),  initials: "KA"),
]

let catalogTracks: [Track] = [
    Track(id: "t1", title: "Never Goodbye",    artist: "NCT DREAM",  album: "DREAM( )SCAPE",       duration: 217,
          gradientStops: [.init(color: Color(hex: "FF5A6E"), location: 0), .init(color: Color(hex: "4A1D3D"), location: 1)],
          dominant: Color(hex: "FF5A6E")),
    Track(id: "t2", title: "Smoothie",          artist: "NCT DREAM",  album: "DREAM( )SCAPE",       duration: 194,
          gradientStops: [.init(color: Color(hex: "F4C26A"), location: 0), .init(color: Color(hex: "B8753C"), location: 1)],
          dominant: Color(hex: "F4C26A")),
    Track(id: "t3", title: "Don't Wanna Cry",   artist: "SEVENTEEN",  album: "AL1",                 duration: 223,
          gradientStops: [.init(color: Color(hex: "6BB6F0"), location: 0), .init(color: Color(hex: "1D3B4A"), location: 1)],
          dominant: Color(hex: "6BB6F0")),
    Track(id: "t4", title: "Spring Day",        artist: "BTS",        album: "You Never Walk Alone", duration: 274,
          gradientStops: [.init(color: Color(hex: "C49AF4"), location: 0), .init(color: Color(hex: "4A1D5E"), location: 1)],
          dominant: Color(hex: "C49AF4")),
    Track(id: "t5", title: "Eight",             artist: "IU, SUGA",   album: "Eight",               duration: 169,
          gradientStops: [.init(color: Color(hex: "7BD389"), location: 0), .init(color: Color(hex: "1D4A2E"), location: 1)],
          dominant: Color(hex: "7BD389")),
    Track(id: "t6", title: "Through the Night", artist: "IU",         album: "Palette",             duration: 254,
          gradientStops: [.init(color: Color(hex: "F5E8D0"), location: 0), .init(color: Color(hex: "806B45"), location: 1)],
          dominant: Color(hex: "F5E8D0")),
    Track(id: "t7", title: "Antifreeze",        artist: "White",      album: "Selene",              duration: 234,
          gradientStops: [.init(color: Color(hex: "A8D8E4"), location: 0), .init(color: Color(hex: "1D3B4A"), location: 1)],
          dominant: Color(hex: "A8D8E4")),
]
