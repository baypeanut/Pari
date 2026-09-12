//
//  TastingService.swift
//  Pari
//
//  Create tastings (wine logs with rating + notes), fetch user's tasting history.
//

import Foundation
import Supabase

enum TastingService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// `vintage` here is the tasting's own vintage; `wines(vintage)` is the catalog row's.
    static let selectColumns = "id, user_id, wine_id, rating, note_tags, comment, created_at, source, visibility, vintage, acidity, tannin, body, sweetness, aroma_intensity, finish, wines(name, producer, vintage, variety, region, label_image_url, category)"

    struct TastingRow: Decodable {
        let id: UUID
        let user_id: UUID
        let wine_id: UUID
        let rating: Double
        let note_tags: [String]?
        let comment: String?
        let created_at: Date
        let source: String?
        let visibility: TastingVisibility
        let vintage: Int?
        let acidity: Int?
        let tannin: Int?
        let body: Int?
        let sweetness: Int?
        let aroma_intensity: Int?
        let finish: Int?
        let wines: WineRef?

        var structure: PalateStructure {
            PalateStructure(
                acidity: acidity, tannin: tannin, body: body,
                sweetness: sweetness, aromaIntensity: aroma_intensity, finish: finish
            )
        }
        var tasting: Tasting? {
            guard let w = wines else { return nil }
            return Tasting(
                id: id, userId: user_id, wineId: wine_id, rating: rating,
                noteTags: note_tags, comment: comment, createdAt: created_at,
                source: source, visibility: visibility, vintage: vintage, structure: structure,
                wine: Wine(id: wine_id, name: w.name, producer: w.producer,
                           vintage: w.vintage, variety: w.variety, region: w.region,
                           labelImageURL: w.label_image_url, category: w.category)
            )
        }

        struct WineRef: Decodable {
            let name: String
            let producer: String
            let vintage: Int?
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
        }
    }

    /// Atomic, replay-safe save. Requires the atomic_tasting_writes migration.
    static func createTasting(_ attempt: TastingSaveAttempt) async throws -> Tasting {
        guard await AuthService.currentUserId() == attempt.userId else {
            throw NSError(domain: "TastingService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: ErrorMessage.unauthorized])
        }
        let row: TastingRow = try await supabase
            .rpc("create_tasting", params: attempt).execute().value
        guard let tasting = row.tasting else { throw missingRowError }
        await didChangeTasting(userId: attempt.userId)
        if await AuthService.currentUserId() == attempt.userId {
            try? await CellarService.removeFromWishlist(wineId: attempt.wineId)
        }
        return tasting
    }

    private static var missingRowError: NSError {
        NSError(domain: "TastingService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "The saved tasting could not be loaded. Please retry."])
    }

    private static func didChangeTasting(userId: UUID) async {
        // Invalidate before observers start fetching recommendations again.
        await TasteVectorCache.shared.invalidate()
        await ProfileStore.shared.refreshTastingCount(userId: userId)
        await MainActor.run {
            NotificationCenter.default.post(name: .pariTastingCreated, object: nil)
        }
    }

    /// Count of user's tastings (cellar / rated wines) for profile stats.
    static func fetchTastingsCount(userId: UUID) async -> Int {
        let response = try? await supabase.from("tastings")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId).execute()
        return response?.count ?? 0
    }

    /// Fetch user's tasting history (most recent first).
    static func fetchTastings(userId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [Tasting] {
        let raw: [TastingRow] = try await supabase
            .from("tastings")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return raw.compactMap(\.tasting)
    }

    /// Fetch like (cheers) counts for a set of tastings keyed by tasting_id.
    static func fetchLikeCountsForTastings(tastingIds: [UUID]) async -> [UUID: Int] {
        guard !tastingIds.isEmpty else { return [:] }
        struct ActivityRow: Decodable {
            let id: UUID
            let tasting_id: UUID?
        }
        let activities: [ActivityRow] = (try? await supabase
            .from("activity_feed")
            .select("id, tasting_id")
            .in("tasting_id", values: tastingIds)
            .execute()
            .value) ?? []

        var activityByTasting: [UUID: UUID] = [:]
        for activity in activities {
            if let tastingId = activity.tasting_id, activityByTasting[tastingId] == nil {
                activityByTasting[tastingId] = activity.id
            }
        }

        let activityIds = Array(Set(activityByTasting.values))
        guard !activityIds.isEmpty else { return [:] }

        struct LikeRow: Decodable { let activity_id: UUID }
        let likes: [LikeRow] = (try? await supabase
            .from("likes")
            .select("activity_id")
            .in("activity_id", values: activityIds)
            .execute()
            .value) ?? []

        var countsByActivity: [UUID: Int] = [:]
        for like in likes {
            countsByActivity[like.activity_id, default: 0] += 1
        }

        var countsByTasting: [UUID: Int] = [:]
        for (tastingId, activityId) in activityByTasting {
            countsByTasting[tastingId] = countsByActivity[activityId, default: 0]
        }
        return countsByTasting
    }

    /// Atomically replace all editable fields and refresh the linked feed content.
    static func updateTasting(
        id: UUID, rating: Double, noteTags: [String]?, comment: String?,
        visibility: TastingVisibility, vintage: Int?, structure: PalateStructure
    ) async throws -> Tasting {
        struct Params: Encodable, Sendable {
            let p_id: UUID
            let p_tasting: TastingWritePayload

            enum CodingKeys: String, CodingKey { case p_id, p_tasting }
            nonisolated func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_id, forKey: .p_id)
                try c.encode(p_tasting, forKey: .p_tasting)
            }
        }
        let row: TastingRow = try await supabase.rpc("update_tasting", params: Params(
            p_id: id,
            p_tasting: TastingWritePayload(rating: rating, noteTags: noteTags, comment: comment,
                visibility: visibility, vintage: vintage, structure: structure)
        )).execute().value
        guard let tasting = row.tasting else { throw missingRowError }
        await didChangeTasting(userId: row.user_id)
        return tasting
    }

    /// The tasting_id foreign key removes only the activity belonging to this log.
    static func deleteTasting(id: UUID) async throws {
        struct Deleted: Decodable { let user_id: UUID }
        let deleted: [Deleted] = try await supabase.from("tastings").delete()
            .eq("id", value: id).select("user_id").execute().value
        guard let row = deleted.first else { throw missingRowError }
        await didChangeTasting(userId: row.user_id)
    }

    /// Fetch wine IDs the user has tasted for fast UI checks.
    static func fetchTastedWineIds(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let wine_id: UUID }
        let rows: [Row] = try await supabase
            .from("tastings")
            .select("wine_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows.map(\.wine_id))
    }
    
    /// Check if user has tasted a specific wine.
    static func hasTasted(userId: UUID, wineId: UUID) async -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await supabase
            .from("tastings")
            .select("id")
            .eq("user_id", value: userId)
            .eq("wine_id", value: wineId)
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }
    
    /// Fetch a specific user's tasting for a wine (if exists).
    static func fetchUserTastingForWine(userId: UUID, wineId: UUID) async throws -> Tasting? {
        let raw: [TastingRow] = try await supabase
            .from("tastings")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .eq("wine_id", value: wineId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return raw.first?.tasting
    }
}
