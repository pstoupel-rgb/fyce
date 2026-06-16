import XCTest
@testable import PhotosPartagees

final class SharedPhotosStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMarkAndContains() {
        let store = SharedPhotosStore(defaults: defaults)
        XCTAssertFalse(store.contains("a"))
        store.markShared("a")
        XCTAssertTrue(store.contains("a"))
        XCTAssertEqual(store.sharedIDs.count, 1)
    }

    func testMarkIsIdempotent() {
        let store = SharedPhotosStore(defaults: defaults)
        store.markShared("a")
        store.markShared("a")
        XCTAssertEqual(store.sharedIDs.count, 1)
    }

    func testPersistenceAcrossInstances() {
        let store = SharedPhotosStore(defaults: defaults)
        store.markShared("x")
        store.markShared("y")

        let reloaded = SharedPhotosStore(defaults: defaults)
        XCTAssertTrue(reloaded.contains("x"))
        XCTAssertTrue(reloaded.contains("y"))
    }

    func testReset() {
        let store = SharedPhotosStore(defaults: defaults)
        store.markShared("a")
        store.reset()
        XCTAssertTrue(store.sharedIDs.isEmpty)

        let reloaded = SharedPhotosStore(defaults: defaults)
        XCTAssertTrue(reloaded.sharedIDs.isEmpty)
    }
}
