//
//  ProfileStore.swift
//  Pari
//
//  Global @Observable current user profile. Updates propagate to Feed and Comments.
//

import Foundation

@MainActor
@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    var currentProfile: Profile?
    var tastingCount: Int = 0

    var expertiseTier: ExpertiseTier { ExpertiseTier(tastingCount: tastingCount) }

    private init() {}

    func load() async {
        let session = AuthStore.shared.sessionGeneration
        guard let uid = await AuthService.currentUserId() else {
            if session == AuthStore.shared.sessionGeneration {
                currentProfile = nil
                tastingCount = 0
            }
            return
        }
        var profile: Profile?
        #if DEBUG
        if !AppConstants.authRequired {
            profile = await DevSignupService.fetchDevAccount(userId: uid)
        }
        #endif
        if profile == nil { profile = try? await AuthService.getProfile(userId: uid) }
        let count = await TastingService.fetchTastingsCount(userId: uid)
        guard session == AuthStore.shared.sessionGeneration,
              AuthStore.shared.currentUserId == uid else { return }
        currentProfile = profile
        tastingCount = count
        AnalyticsService.identify(userId: uid)
    }

    /// Use the server count so a replayed save never increments the count twice.
    func refreshTastingCount(userId: UUID) async {
        let session = AuthStore.shared.sessionGeneration
        let count = await TastingService.fetchTastingsCount(userId: userId)
        guard session == AuthStore.shared.sessionGeneration,
              AuthStore.shared.currentUserId == userId else { return }
        tastingCount = count
    }

    /// Clear cached profile (e.g. on sign out in dev mode).
    func clearForSignOut() {
        currentProfile = nil
        tastingCount = 0
        AnalyticsService.reset()
    }

    /// Update local state after profile edit. Feed/Comments use this for current user override.
    func updateLocal(_ profile: Profile) {
        currentProfile = profile
    }
}
