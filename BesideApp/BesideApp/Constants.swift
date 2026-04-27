import Foundation

enum AppLinks {
    // 公開 URL 確定後に差し替える(M6 仮値)
    static let termsOfService = URL(string: "https://example.com/beside/terms")!
    static let privacyPolicy  = URL(string: "https://example.com/beside/privacy")!
    static let supportMail    = URL(string: "mailto:support@example.com")!
}
