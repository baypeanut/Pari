//
//  SupabaseManager.swift
//  Pari
//
//  Shared singleton for Supabase connection. Uses SupabaseConfig for credentials.
//

import Foundation
import Supabase

/// Central Supabase client. All services use this shared instance.
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let client: SupabaseClient

    private init() {
        // Authenticated responses (including private photos) must be reauthorized
        // on each fetch. Auth tokens remain in the SDK's separate auth storage.
        let transport = URLSessionConfiguration.ephemeral
        transport.urlCache = nil
        transport.requestCachePolicy = .reloadIgnoringLocalCacheData
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true),
            global: .init(session: URLSession(configuration: transport))
        )
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }

    /// Use for Auth, Postgrest, Storage, Realtime.
    var supabase: SupabaseClient { client }
}
