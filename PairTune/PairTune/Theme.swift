import SwiftUI

extension Color {
    // Base palette
    static let pairtuneBase          = Color(hex: "0A0A0A")
    static let pairtuneSurface       = Color(hex: "141414")
    static let pairtuneSurfaceSheet  = Color(hex: "1A1A1A")
    static let pairtuneSurfaceHi     = Color(hex: "1C1C1C")
    static let pairtuneHairline      = Color(hex: "262626")

    // Accent
    static let pairtuneCoral  = Color(hex: "FF5A6E")
    static let pairtuneCream  = Color(hex: "F5E8D0")

    // Text
    static let pairtuneTextPrimary    = Color.white
    static let pairtuneTextSecondary  = Color(hex: "A8A8A8")
    static let pairtuneTextTertiary   = Color(hex: "6B6B6B")
    static let pairtuneTextQuaternary = Color(hex: "3F3F3F")

    // Status
    static let pairtuneSyncOk   = Color(hex: "7BD389")
    static let pairtuneSyncWarn = Color(hex: "F4C26A")
    static let pairtuneSyncBad  = Color(hex: "E85B6B")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}
