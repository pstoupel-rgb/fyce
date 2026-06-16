import XCTest
@testable import PhotosPartagees

final class FaceMatcherTests: XCTestCase {

    func testHasNoReferenceInitially() {
        let matcher = FaceMatcher()
        XCTAssertFalse(matcher.hasReference)
    }

    func testMatchReturnsNilWithoutReference() {
        let matcher = FaceMatcher()
        XCTAssertNil(matcher.match(against: []))
    }

    func testThresholdIsConfigurable() {
        let matcher = FaceMatcher()
        matcher.threshold = 0.42
        XCTAssertEqual(matcher.threshold, 0.42, accuracy: 0.0001)
    }
}
