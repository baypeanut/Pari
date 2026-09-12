import Foundation

struct OwnedBottle: Identifiable, Sendable {
    let id: UUID
    let wine: Wine
    let vintage: Int?
    let quantity: Int
    let location: String?
}

struct CellarStockResult: Decodable, Sendable {
    let bottle_id: UUID
    let quantity: Int
}

/// Held unchanged until the server confirms the stock change.
struct AddBottlesRequest: Encodable, Sendable {
    let requestId: UUID
    let wineId: UUID
    let quantity: Int
    let vintage: Int?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "p_request_id", wineId = "p_wine_id", quantity = "p_quantity"
        case vintage = "p_vintage", location = "p_location"
    }
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(requestId, forKey: .requestId)
        try c.encode(wineId, forKey: .wineId)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(vintage, forKey: .vintage)
        try c.encode(location, forKey: .location)
    }
}

struct DrinkBottleRequest: Encodable, Sendable {
    let requestId: UUID
    let bottleId: UUID

    enum CodingKeys: String, CodingKey { case requestId = "p_request_id", bottleId = "p_bottle_id" }
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(requestId, forKey: .requestId)
        try c.encode(bottleId, forKey: .bottleId)
    }
}

enum BottleInput {
    /// Blank means unknown. Invalid input must never silently become unknown.
    static func vintage(from text: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let year = Int(trimmed), (1800...2100).contains(year) else {
            throw ValidationError.invalidVintage
        }
        return year
    }

    enum ValidationError: LocalizedError {
        case invalidVintage
        var errorDescription: String? { "Enter a vintage between 1800 and 2100, or leave it blank." }
    }
}
