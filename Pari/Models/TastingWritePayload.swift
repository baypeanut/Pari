import Foundation

/// A complete edit, including explicit nulls for answers the user cleared.
struct TastingWritePayload: Encodable, Sendable {
    let rating: Double
    let noteTags: [String]?
    let comment: String?
    let visibility: TastingVisibility
    let vintage: Int?
    let structure: PalateStructure

    enum CodingKeys: String, CodingKey {
        case rating, comment, visibility, vintage, acidity, tannin, body, sweetness, finish
        case noteTags = "note_tags"
        case aromaIntensity = "aroma_intensity"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rating, forKey: .rating)
        try c.encode(noteTags?.isEmpty == false ? noteTags?.sorted() : nil, forKey: .noteTags)
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        try c.encode(trimmed?.isEmpty == false ? trimmed : nil, forKey: .comment)
        try c.encode(visibility.rawValue, forKey: .visibility)
        try c.encode(vintage, forKey: .vintage)
        try c.encode(structure.acidity, forKey: .acidity)
        try c.encode(structure.tannin, forKey: .tannin)
        try c.encode(structure.body, forKey: .body)
        try c.encode(structure.sweetness, forKey: .sweetness)
        try c.encode(structure.aromaIntensity, forKey: .aromaIntensity)
        try c.encode(structure.finish, forKey: .finish)
    }
}

/// Retained by the save screen until confirmed, so retries send the same ID and
/// snapshot. The server derives ownership from auth.uid(), never from this userId.
struct TastingSaveAttempt: Encodable, Sendable {
    let id: UUID
    let userId: UUID
    let wineId: UUID
    let tasting: TastingWritePayload
    let source: String
    let momentImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id = "p_id", wineId = "p_wine_id", tasting = "p_tasting"
        case source = "p_source", momentImageURL = "p_moment_image_url"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(wineId, forKey: .wineId)
        try c.encode(tasting, forKey: .tasting)
        try c.encode(source, forKey: .source)
        try c.encode(momentImageURL, forKey: .momentImageURL)
    }
}
