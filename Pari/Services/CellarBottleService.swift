//
//  CellarBottleService.swift
//  Pari
//
//  Bottles you own, and which one to open tonight.
//
//  This is the only question in the app with a recurring answer. Logging happens when
//  you drink; deciding what to drink happens every time you look at the rack.
//

import Foundation
import Supabase

struct CellarBottle: Identifiable, Sendable {
    /// How close a bottle is to the end of its window. Drives ordering and the label.
    enum Urgency: String, Sendable {
        case past          // window has closed
        case drinkNow      // closing within a year
        case ready
        case stillYoung
        case unknown

        init(rawValue: String) {
            switch rawValue {
            case "past": self = .past
            case "drink now": self = .drinkNow
            case "ready": self = .ready
            case "still young": self = .stillYoung
            default: self = .unknown
            }
        }

        var label: String {
            switch self {
            case .past: return "Past its window"
            case .drinkNow: return "Drink now"
            case .ready: return "Ready"
            case .stillYoung: return "Still young"
            case .unknown: return "No window yet"
            }
        }
    }

    let id: UUID
    let wine: Wine
    let vintage: Int?
    let quantity: Int
    let drinkFromYear: Int?
    let drinkUntilYear: Int?
    let yearsLeft: Int?
    let affinity: Double?
    let urgency: Urgency
}

enum CellarBottleService {
    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// What to open, urgency first. A bottle closing this year outranks a slightly
    /// better match with five years left, because the better match will still be there.
    static func openTonight(limit: Int = 10) async -> [CellarBottle] {
        guard let userId = await AuthService.currentUserId() else { return [] }

        struct Params: Encodable, Sendable {
            let p_user_id: String
            let p_limit: Int
            private enum CodingKeys: String, CodingKey { case p_user_id, p_limit }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_user_id, forKey: .p_user_id)
                try c.encode(p_limit, forKey: .p_limit)
            }
        }
        struct Row: Decodable {
            let bottle_id: UUID
            let wine_id: UUID
            let name: String
            let producer: String
            let vintage: Int?
            let region: String?
            let category: String?
            let label_image_url: String?
            let quantity: Int
            let drink_from_year: Int?
            let drink_until_year: Int?
            let years_left: Int?
            let affinity: Double?
            let urgency: String
        }

        do {
            let rows: [Row] = try await supabase
                .rpc("open_tonight", params: Params(p_user_id: userId.uuidString, p_limit: limit))
                .execute().value

            return rows.map { row in
                CellarBottle(
                    id: row.bottle_id,
                    wine: Wine(id: row.wine_id, name: row.name, producer: row.producer,
                               vintage: row.vintage, variety: nil, region: row.region,
                               labelImageURL: row.label_image_url, category: row.category),
                    vintage: row.vintage,
                    quantity: row.quantity,
                    drinkFromYear: row.drink_from_year,
                    drinkUntilYear: row.drink_until_year,
                    yearsLeft: row.years_left,
                    affinity: row.affinity,
                    urgency: CellarBottle.Urgency(rawValue: row.urgency)
                )
            }
        } catch {
            #if DEBUG
            print("[CellarBottleService] openTonight failed: \(error)")
            #endif
            return []
        }
    }

    /// Owned stock is a separate surface from tasting history. Fetch every page,
    /// so a large cellar is not silently truncated by PostgREST's row limit.
    static func fetchOwnedBottles() async throws -> [OwnedBottle] {
        guard let userId = await AuthService.currentUserId() else { throw StockError.unauthorized }
        let session = AuthStore.shared.sessionGeneration
        var result: [OwnedBottle] = []
        let pageSize = 200
        var offset = 0
        while true {
            let rows: [InventoryRow] = try await supabase.from("cellar_bottles")
                .select("id, wine_id, vintage, quantity, location, wines(name, producer, variety, region, label_image_url, category)")
                .eq("user_id", value: userId).gt("quantity", value: 0)
                .order("created_at", ascending: false).order("id", ascending: true)
                .range(from: offset, to: offset + pageSize - 1).execute().value
            guard session == AuthStore.shared.sessionGeneration, !Task.isCancelled else { throw CancellationError() }
            result.append(contentsOf: rows.map(\.bottle))
            if rows.count < pageSize { return result }
            offset += pageSize
        }
    }

    struct InventoryRow: Decodable {
        let id: UUID
        let wine_id: UUID
        let vintage: Int?
        let quantity: Int
        let location: String?
        let wines: WineRef

        struct WineRef: Decodable {
            let name: String
            let producer: String
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
        }

        var bottle: OwnedBottle {
            OwnedBottle(id: id,
                wine: Wine(id: wine_id, name: wines.name, producer: wines.producer,
                    vintage: vintage, variety: wines.variety, region: wines.region,
                    labelImageURL: wines.label_image_url, category: wines.category),
                vintage: vintage, quantity: quantity, location: location)
        }
    }

    /// The caller keeps requestId until confirmation, including across retries.
    static func addBottles(_ request: AddBottlesRequest) async throws -> CellarStockResult {
        try await supabase.rpc("add_cellar_bottles", params: request).execute().value
    }

    static func drinkOne(_ request: DrinkBottleRequest) async throws -> CellarStockResult {
        do {
            return try await supabase.rpc("drink_cellar_bottle", params: request).execute().value
        } catch let error as PostgrestError where error.code == "P0002" {
            throw StockError.unavailable
        }
    }

    enum StockError: LocalizedError {
        case unauthorized, unavailable
        var errorDescription: String? {
            switch self {
            case .unauthorized: return ErrorMessage.unauthorized
            case .unavailable: return "This bottle is unavailable or already empty."
            }
        }
    }
}
