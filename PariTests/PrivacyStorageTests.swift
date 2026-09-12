import XCTest
@testable import Pari

final class PrivacyStorageTests: XCTestCase {
    private let path = "00000000-0000-0000-0000-000000000001/moment.jpg"

    @MainActor
    func testReturningToSameAccountUsesANewSessionGeneration() async {
        let store = AuthStore()
        let user = UUID()
        store.currentUserId = user
        let original = store.sessionGeneration
        store.currentUserId = nil
        store.currentUserId = user
        XCTAssertNotEqual(store.sessionGeneration, original,
                          "A response from before logout must not repopulate the new session")
    }

    func testHistoricalPublicURLIsOnlyUsedAsObjectReference() {
        XCTAssertEqual(MomentStorageService.objectPath(from:
            "https://example.supabase.co/storage/v1/object/public/moment_images/\(path)"), path)
        XCTAssertEqual(MomentStorageService.objectPath(from: path), path)
    }

    func testUnexpectedPhotoReferencesAreRejected() {
        for value in ["https://example.com/photo.jpg", "../photo.jpg", "user/photo.jpg",
                      "\(path)?token=123", "\(path)/extra", "\(path)%2Fsecret"] {
            XCTAssertNil(MomentStorageService.objectPath(from: value), value)
        }
    }

    func testLegacyFeedFilesArePurgedWithoutDeletingOtherCaches() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["pari_feed_global_v5.json", "pari_feed_following_v4.json", "catalog.json"] {
            try Data("private content".utf8).write(to: directory.appendingPathComponent(name))
        }
        FeedCache.clearLegacyFiles(directory: directory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["catalog.json"])
    }
}
