import XCTest
@testable import Pari

final class ProfileLoadingTests: XCTestCase {
    @MainActor
    func testFailedHistoryIsNotShownAsEmptyAndCanBeRetried() async {
        var attempts = 0
        let model = ProfileViewModel(userId: UUID(), fetchTastings: { _ in
            attempts += 1
            if attempts == 1 { throw URLError(.badServerResponse) }
            return []
        }, fetchCheers: { _ in [:] })
        XCTAssertFalse(model.showsEmptyTastings)
        await model.reloadTastings()
        XCTAssertNotNil(model.tastingsErrorMessage)
        XCTAssertFalse(model.showsEmptyTastings)
        XCTAssertFalse(model.isLoadingTastings)
        await model.reloadTastings()
        XCTAssertNil(model.tastingsErrorMessage)
        XCTAssertTrue(model.showsEmptyTastings)
    }

    @MainActor
    func testFailedRefreshPreservesPreviouslyLoadedHistory() async {
        let user = UUID()
        let wine = Wine(id: UUID(), name: "Test wine", producer: "Test producer")
        let tasting = Tasting(id: UUID(), userId: user, wineId: wine.id,
                              rating: 8, createdAt: Date(), wine: wine)
        var attempts = 0
        let model = ProfileViewModel(userId: user, fetchTastings: { requestedUser in
            XCTAssertEqual(requestedUser, user)
            attempts += 1
            if attempts > 1 { throw URLError(.notConnectedToInternet) }
            return [tasting]
        }, fetchCheers: { _ in [:] })
        await model.reloadTastings()
        await model.reloadTastings()
        XCTAssertEqual(model.recentTastingsTop5.map(\.id), [tasting.id])
        XCTAssertNotNil(model.tastingsErrorMessage)
        XCTAssertFalse(model.showsEmptyTastings)
    }

    @MainActor
    func testAnOlderFailedRequestCannotOverwriteSuccessfulRetry() async {
        var pending: CheckedContinuation<[Tasting], Error>?
        var attempts = 0
        let model = ProfileViewModel(userId: UUID(), fetchTastings: { _ in
            attempts += 1
            if attempts == 1 {
                return try await withCheckedThrowingContinuation { pending = $0 }
            }
            return []
        }, fetchCheers: { _ in [:] })
        let old = Task { await model.reloadTastings() }
        while pending == nil { await Task.yield() }
        await model.reloadTastings()
        pending?.resume(throwing: URLError(.timedOut))
        await old.value
        XCTAssertNil(model.tastingsErrorMessage)
        XCTAssertTrue(model.showsEmptyTastings)
        XCTAssertFalse(model.isLoadingTastings)
    }
}
