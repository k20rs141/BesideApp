import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let info = Bundle.main.infoDictionary
        guard
            let urlString = info?["SUPABASE_URL"] as? String,
            let anonKey = info?["SUPABASE_ANON_KEY"] as? String,
            !urlString.isEmpty, urlString != "https://your-project-id.supabase.co",
            let url = URL(string: urlString)
        else {
            fatalError("Config.xcconfig に SUPABASE_URL / SUPABASE_ANON_KEY を設定してください")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}
