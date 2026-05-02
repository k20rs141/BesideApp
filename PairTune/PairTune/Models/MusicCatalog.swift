import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let artworkURL: URL?
}

struct Album: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let artworkURL: URL?
}
