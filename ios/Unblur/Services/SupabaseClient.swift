import Foundation
import Supabase

extension SupabaseClient {
    static let shared: SupabaseClient = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not configured in Info.plist via Supabase.xcconfig")
        }
        guard let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist via Supabase.xcconfig")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
