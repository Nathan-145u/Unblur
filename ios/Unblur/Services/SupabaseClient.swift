import Foundation
import Supabase

enum SupabaseClientFactory {
    static let shared: SupabaseClient = {
        guard let supabaseURL = URL(string: Secrets.supabaseURL) else {
            fatalError("Invalid SUPABASE_URL in .env. Run sync-env.sh after updating .env.")
        }
        return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: Secrets.supabaseAnonKey)
    }()
}
