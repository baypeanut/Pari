//
//  ProfileViewModel.swift
//  Pari
//
//  Beli-style profile data: profile, stats, recent activity, taste profile, streak.
//  Keyed by userId; never overrides with current user. All fetches use self.userId only.
//

import Foundation
import UIKit

private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

@MainActor
@Observable
final class ProfileViewModel {
    let userId: UUID
    var isOwn: Bool = false

    var profile: Profile?
    var ratedCount: Int = 0
    var followersCount: Int = 0
    var followingCount: Int = 0
    var recentActivity: [FeedItem] = []
    var allTastings: [Tasting] = []
    var tastingCheersCounts: [UUID: Int] = [:]
    var tasteGrapes: [TasteProfileItem] = []
    var tasteRegions: [TasteProfileItem] = []
    var tasteStyles: [TasteProfileItem] = []
    var wishlistPreview: [CellarItem] = []
    var myWishlistWineIds: Set<UUID> = []
    var wishlistToggleError: String?
    var privacySettings: PrivacySettings = .default
    var isViewerFriend: Bool = false
    var isLoadingInitial = true
    var isRefreshing = false
    var errorMessage: String?
    var isLoading: Bool { isLoadingInitial || isRefreshing }

    private var loadId = UUID()
    private var tastingLoadId = UUID()
    private let fetchTastings: (UUID) async throws -> [Tasting]
    private let fetchCheers: ([UUID]) async -> [UUID: Int]
    private(set) var isLoadingTastings = false
    private(set) var hasLoadedTastings = false
    private(set) var tastingsErrorMessage: String?

    var showsEmptyTastings: Bool {
        hasLoadedTastings && !isLoadingTastings && tastingsErrorMessage == nil && allTastings.isEmpty
    }

    /// Top 5 tastings for Recent Activity; sorted by createdAt desc (tastedAt when in schema).
    var recentTastingsTop5: [Tasting] {
        let sorted = allTastings.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(5))
    }

    /// Visibility for another user's profile sections. Own profile: always true.
    var cellarVisible: Bool {
        isOwn || privacySettings.cellarVisibility == .everyone || (privacySettings.cellarVisibility == .friends && isViewerFriend)
    }
    var wishlistVisible: Bool {
        isOwn || privacySettings.wishlistVisibility == .everyone || (privacySettings.wishlistVisibility == .friends && isViewerFriend)
    }
    var activityVisible: Bool {
        isOwn || privacySettings.activityVisibility == .everyone || (privacySettings.activityVisibility == .friends && isViewerFriend)
    }

    init(
        userId: UUID,
        fetchTastings: @escaping (UUID) async throws -> [Tasting] = { try await TastingService.fetchTastings(userId: $0, limit: 200) },
        fetchCheers: @escaping ([UUID]) async -> [UUID: Int] = { await TastingService.fetchLikeCountsForTastings(tastingIds: $0) }
    ) {
        self.userId = userId
        self.fetchTastings = fetchTastings
        self.fetchCheers = fetchCheers
    }

    /// A failed request is not an empty history. Keep previously loaded entries
    /// visible and let the user retry this section without reloading the profile.
    func reloadTastings() async {
        let requestId = UUID()
        tastingLoadId = requestId
        isLoadingTastings = true
        tastingsErrorMessage = nil
        defer { if tastingLoadId == requestId { isLoadingTastings = false } }
        do {
            let tastings = try await fetchTastings(userId)
            let cheers = await fetchCheers(tastings.map(\.id))
            guard tastingLoadId == requestId, !Task.isCancelled else { return }
            allTastings = tastings
            tastingCheersCounts = cheers
            let taste = ProfileService.computeTasteProfile(from: tastings)
            tasteGrapes = taste.grapes
            tasteRegions = taste.regions
            tasteStyles = taste.styles
            hasLoadedTastings = true
        } catch {
            guard tastingLoadId == requestId, !isCancellation(error) else { return }
            tastingsErrorMessage = "Could not load tastings. Please try again."
        }
    }

    func load() async {
        let uid = userId
        let currentLoadId = UUID()
        loadId = currentLoadId
        let isFirstLoad = allTastings.isEmpty && profile == nil
        if isFirstLoad {
            isLoadingInitial = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil
        wishlistToggleError = nil

        var newProfile: Profile?
        var newRatedCount: Int?
        var newFollowersCount: Int?
        var newFollowingCount: Int?
        var newWishlistPreview: [CellarItem]?
        var newMyWishlistWineIds: Set<UUID>?

        let current = await AuthService.currentUserId()
        guard loadId == currentLoadId else { return }
        isOwn = (current == uid)

        do {
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                guard loadId == currentLoadId else { return }
                newProfile = dev
            } else {
                let p = try await AuthService.getProfile(userId: uid)
                guard loadId == currentLoadId else { return }
                newProfile = p
            }
        } catch {
            guard loadId == currentLoadId else { return }
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }

        let countTask = Task { await TastingService.fetchTastingsCount(userId: uid) }
        let followersTask = Task { await SocialService.fetchFollowerCount(userId: uid) }
        let followingTask = Task { await SocialService.fetchFollowingCount(userId: uid) }
        let tastingsTask = Task { await self.reloadTastings() }
        let wishlistTask = Task { try await CellarService.fetchWishlist(userId: uid, limit: 15) }
        let myWishlistTask: Task<Set<UUID>, Error>? = (current != nil && current != uid) ? Task { try await CellarService.fetchWishlistWineIds(userId: current!) } : nil
        let privacyTask = Task { try? await ProfileService.fetchPrivacySettings(userId: uid) }
        let isFriendTask: Task<Bool, Never>? = (current != nil && current != uid) ? Task { await ProfileService.isMutualFriend(viewerId: current!, ownerId: uid) } : Task { true }

        newRatedCount = await countTask.value
        guard loadId == currentLoadId else { return }
        newFollowersCount = await followersTask.value
        guard loadId == currentLoadId else { return }
        newFollowingCount = await followingTask.value
        guard loadId == currentLoadId else { return }

        await tastingsTask.value
        guard loadId == currentLoadId else { return }

        do {
            let items = try await wishlistTask.value
            guard loadId == currentLoadId else { return }
            newWishlistPreview = items
        } catch {
            guard loadId == currentLoadId else { return }
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }

        if let task = myWishlistTask {
            newMyWishlistWineIds = (try? await task.value) ?? []
        }
        let loadedPrivacy = await privacyTask.value
        let loadedFriend = await (isFriendTask?.value ?? true)
        guard loadId == currentLoadId else { return }
        if let loadedPrivacy { privacySettings = loadedPrivacy }
        isViewerFriend = loadedFriend

        if let p = newProfile { profile = p }
        if let c = newRatedCount { ratedCount = c }
        if let f = newFollowersCount { followersCount = f }
        if let f = newFollowingCount { followingCount = f }
        if let w = newWishlistPreview { wishlistPreview = w }
        if let w = newMyWishlistWineIds { myWishlistWineIds = w }

        isLoadingInitial = false
        isRefreshing = false
    }

    /// Remove wine from own wishlist. Used when viewing own profile tab.
    func removeFromWishlist(_ item: CellarItem) async {
        do {
            try await CellarService.removeFromWishlist(wineId: item.wineId)
            wishlistPreview.removeAll { $0.id == item.id }
            NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
        } catch {
            wishlistToggleError = "Could not remove."
        }
    }

    /// Toggle wishlist from profile (when viewing another user's Reserve List). Optimistic update; reverts on failure.
    func toggleWishlistFromProfile(_ item: CellarItem) async {
        guard let cur = await AuthService.currentUserId(), cur != userId else { return }
        let wineId = item.wineId
        let wasIn = myWishlistWineIds.contains(wineId)
        wishlistToggleError = nil
        if wasIn {
            myWishlistWineIds.remove(wineId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                try await CellarService.removeFromWishlist(wineId: wineId)
                NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            } catch {
                myWishlistWineIds.insert(wineId)
                wishlistToggleError = "Could not update."
            }
            return
        }
        myWishlistWineIds.insert(wineId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let added = try await CellarService.addToWishlist(wineId: wineId, sourceUserId: userId, sourceContext: "wishlist")
            if added {
                AnalyticsService.wishlistSaveFromUser(wineId: wineId, sourceUserId: userId)
                NotificationCenter.default.post(name: .pariWishlistUpdated, object: nil)
            } else {
                myWishlistWineIds.remove(wineId)
                NotificationCenter.default.post(name: .pariAlreadyTastedToast, object: nil)
            }
        } catch {
            myWishlistWineIds.remove(wineId)
            wishlistToggleError = "Could not update."
        }
    }
}
