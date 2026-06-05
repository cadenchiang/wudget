import Foundation
import Supabase

/// Central Supabase client configuration for Orbit.
///
/// Exposes the project URL, the publishable anon key, and a shared `SupabaseClient`
/// used for authentication (and, later, expense sync). The anon key is safe to embed
/// in the app: it only grants access permitted by Row Level Security policies.
/// The service-role key and database password must NEVER appear in this repo;
/// they live outside the checkout (see .gitignore note).
enum SupabaseService {
    /// Supabase project ref, used to sanity-check the URL and key in tests.
    static let projectRef = "lydothopnwymmjmtgpdv"

    /// Supabase project URL. Built from a constant; invalid input is a programmer
    /// error, so failure aborts in development rather than being silently ignored.
    static let projectURL: URL = {
        let urlString = "https://\(projectRef).supabase.co"
        guard let url = URL(string: urlString) else {
            Log.auth.fault("Invalid Supabase project URL: \(urlString, privacy: .public)")
            preconditionFailure("Invalid Supabase project URL: \(urlString)")
        }
        return url
    }()

    /// Publishable anon key (public by design; RLS enforces all data access).
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5ZG90aG9wbnd5bW1qbXRncGR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2Njg5MDcsImV4cCI6MjA5NjI0NDkwN30.ADjxGZpqErRujNVVydoIUMOPuOgqytmf5MPwaV5KtrU"

    /// Shared Supabase client. All auth (and future sync) calls go through this
    /// single instance so session state is consistent across the app.
    static let client = SupabaseClient(supabaseURL: projectURL, supabaseKey: anonKey)
}
