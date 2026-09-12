import XCTest
@testable import Pari

final class CellarInventoryTests: XCTestCase {
    func testBlankVintageIsUnknown() throws {
        XCTAssertNil(try BottleInput.vintage(from: "  "))
    }

    func testValidVintageIsPreserved() throws {
        XCTAssertEqual(try BottleInput.vintage(from: " 2021 "), 2021)
        XCTAssertEqual(try BottleInput.vintage(from: "1800"), 1800)
        XCTAssertEqual(try BottleInput.vintage(from: "2100"), 2100)
    }

    func testInvalidVintageDoesNotSilentlyBecomeUnknown() {
        for text in ["202x", "1799", "2101", "-1", "2020.5"] {
            XCTAssertThrowsError(try BottleInput.vintage(from: text), text)
        }
    }

    func testAddPayloadCarriesStableRequestAndExplicitUnknownVintage() throws {
        let id = UUID()
        let request = AddBottlesRequest(requestId: id, wineId: UUID(), quantity: 3, vintage: nil, location: nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(json["p_request_id"] as? String, id.uuidString)
        XCTAssertEqual(json["p_quantity"] as? Int, 3)
        XCTAssertTrue(json["p_vintage"] is NSNull)
        XCTAssertNil(json["user_id"])
    }

    func testInventoryRowPreservesOwnedVintageQuantityAndLocation() throws {
        let json = """
        {"id":"30000000-0000-0000-0000-000000000001",
         "wine_id":"10000000-0000-0000-0000-000000000001",
         "vintage":2020,"quantity":3,"location":"Kitchen rack",
         "wines":{"name":"Fixture wine","producer":"Fixture producer"}}
        """
        let row = try JSONDecoder().decode(CellarBottleService.InventoryRow.self, from: Data(json.utf8))
        XCTAssertEqual(row.bottle.quantity, 3)
        XCTAssertEqual(row.bottle.vintage, 2020)
        XCTAssertEqual(row.bottle.wine.vintage, 2020)
        XCTAssertEqual(row.bottle.location, "Kitchen rack")
    }

    @MainActor
    func testLostResponseRetriesTheSameOpeningInsteadOfOpeningAnotherBottle() async {
        let bottle = fixture(quantity: 2)
        var requests: [UUID] = []
        let session = UUID()
        let model = BottleInventoryViewModel(fetch: { [self] in [fixture(quantity: requests.isEmpty ? 2 : 1)] },
            drink: { request in
                requests.append(request.requestId)
                if requests.count == 1 { throw URLError(.timedOut) }
                return CellarStockResult(bottle_id: bottle.id, quantity: 1)
            }, session: { session }, notify: {})
        await model.load()
        await model.openOne(bottle)
        XCTAssertEqual(model.totalBottles, 2)
        XCTAssertTrue(model.isAwaitingConfirmation(bottle.id))
        await model.openOne(bottle)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
        XCTAssertEqual(model.totalBottles, 1)
        XCTAssertFalse(model.isAwaitingConfirmation(bottle.id))
    }

    @MainActor
    func testFailedRefreshAfterConfirmedOpeningPreventsAnExtraDecrement() async {
        let bottle = fixture(quantity: 2)
        var calls = 0
        let session = UUID()
        let model = BottleInventoryViewModel(fetch: {
            if calls > 0 { throw URLError(.notConnectedToInternet) }
            return [bottle]
        }, drink: { _ in
            calls += 1
            return CellarStockResult(bottle_id: bottle.id, quantity: 1)
        }, session: { session }, notify: {})
        await model.load()
        await model.openOne(bottle)
        XCTAssertEqual(model.totalBottles, 1)
        XCTAssertNotNil(model.errorMessage)
        await model.openOne(bottle)
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testOldSessionCannotApplyAnOpeningResponse() async {
        let bottle = fixture(quantity: 2)
        var session = UUID()
        let model = BottleInventoryViewModel(fetch: { [bottle] }, drink: { _ in
            session = UUID()
            return CellarStockResult(bottle_id: bottle.id, quantity: 1)
        }, session: { session }, notify: {})
        await model.load()
        await model.openOne(bottle)
        XCTAssertEqual(model.totalBottles, 2)
    }

    @MainActor
    func testUnavailableBottleRefreshesInventoryAndClearsPendingRequest() async {
        let bottle = fixture(quantity: 1)
        var attempted = false
        let session = UUID()
        let model = BottleInventoryViewModel(fetch: { attempted ? [] : [bottle] }, drink: { _ in
            attempted = true
            throw CellarBottleService.StockError.unavailable
        }, session: { session }, notify: {})
        await model.load()
        await model.openOne(bottle)
        XCTAssertTrue(model.bottles.isEmpty)
        XCTAssertFalse(model.isAwaitingConfirmation(bottle.id))
        XCTAssertNotNil(model.mutationError)
    }

    private func fixture(quantity: Int) -> OwnedBottle {
        OwnedBottle(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            wine: Wine(id: UUID(), name: "Fixture wine", producer: "Fixture producer", vintage: 2020,
                       variety: nil, region: nil, labelImageURL: nil),
            vintage: 2020, quantity: quantity, location: "Kitchen rack")
    }
}
