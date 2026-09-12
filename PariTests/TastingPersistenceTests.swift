import XCTest
@testable import Pari

final class TastingPersistenceTests: XCTestCase {
    func testClearedAnswersAreExplicitNulls() throws {
        let payload = TastingWritePayload(rating: 8, noteTags: [], comment: "  \n",
            visibility: .friends, vintage: nil, structure: .empty)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        for key in ["note_tags", "comment", "vintage", "acidity", "tannin", "body", "sweetness", "aroma_intensity", "finish"] {
            XCTAssertTrue(json[key] is NSNull, "Omitting \(key) would leave an old answer behind")
        }
        XCTAssertEqual(json["visibility"] as? String, "friends")
    }

    func testEditIncludesEveryStructureAnswer() throws {
        let payload = TastingWritePayload(rating: 7.5, noteTags: ["Cherry"], comment: " Dinner ",
            visibility: .friends, vintage: 2021,
            structure: PalateStructure(acidity: 1, tannin: 2, body: 3, sweetness: 4, aromaIntensity: 5, finish: 2))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        for (key, value) in ["acidity": 1, "tannin": 2, "body": 3, "sweetness": 4, "aroma_intensity": 5, "finish": 2, "vintage": 2021] {
            XCTAssertEqual(json[key] as? Int, value)
        }
        XCTAssertEqual(json["comment"] as? String, "Dinner")
    }

    func testReplayKeepsIdentityAndDoesNotSendOwner() throws {
        let attempt = TastingSaveAttempt(id: UUID(), userId: UUID(), wineId: UUID(),
            tasting: TastingWritePayload(rating: 8, noteTags: nil, comment: nil,
                visibility: .friends, vintage: nil, structure: .empty), source: "search", momentImageURL: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(attempt), try encoder.encode(attempt))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(attempt)) as? [String: Any])
        XCTAssertEqual(json["p_id"] as? String, attempt.id.uuidString)
        XCTAssertNil(json["userId"])
        XCTAssertNil(json["user_id"])
    }

    func testFetchedTastingPreservesVisibilityAndBottleDetails() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(TastingService.TastingRow.self, from: Data(rowJSON.utf8))
        let tasting = try XCTUnwrap(row.tasting)
        XCTAssertEqual(tasting.visibility, .friends)
        XCTAssertEqual(tasting.vintage, 2021)
        XCTAssertEqual(tasting.wine.vintage, 2019)
        XCTAssertEqual(tasting.structure, PalateStructure(acidity: 2, tannin: 3, body: 4,
            sweetness: 1, aromaIntensity: 5, finish: 4))
        XCTAssertTrue(TastingService.selectColumns.contains("visibility"))
    }

    func testMissingVisibilityCannotSilentlyBecomePublic() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = rowJSON.replacingOccurrences(of: "\"visibility\":\"friends\",", with: "")
        XCTAssertThrowsError(try decoder.decode(TastingService.TastingRow.self, from: Data(json.utf8)))
    }

    private var rowJSON: String {
        """
        {"id":"30000000-0000-0000-0000-000000000001",
         "user_id":"00000000-0000-0000-0000-000000000001",
         "wine_id":"10000000-0000-0000-0000-000000000001",
         "rating":8,"created_at":"2026-09-11T12:00:00Z","visibility":"friends",
         "vintage":2021,"acidity":2,"tannin":3,"body":4,"sweetness":1,"aroma_intensity":5,"finish":4,
         "wines":{"name":"Test wine","producer":"Test producer","vintage":2019}}
        """
    }
}
