import Foundation
import Supabase

nonisolated enum SupabaseClientProvider {
    static let shared: SupabaseClient? = {
        let info = Bundle.main.infoDictionary
        let url = (info?["SupabaseURL"] as? String) ?? ""
        let key = (info?["SupabaseAnonKey"] as? String) ?? ""
        guard !url.isEmpty, !key.isEmpty, let supabaseURL = URL(string: url) else {
            return nil
        }
        return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
    }()
}
