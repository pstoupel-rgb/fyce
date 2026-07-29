import XCTest
@testable import PhotosPartagees

final class EventInviteTests: XCTestCase {

    func testInviteRoundTrip() {
        let event = PozeEvent(name: "Anniv Léa",
                              date: Date(timeIntervalSince1970: 1_800_000_000),
                              colorway: .candy,
                              symbol: "party.popper.fill")
        let encoded = EventInvite(event: event).encoded()

        XCTAssertTrue(encoded.hasPrefix("poze://join/"))

        let decoded = EventInvite.decode(from: encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.id, event.id)
        XCTAssertEqual(decoded?.name, "Anniv Léa")
        XCTAssertEqual(decoded?.code, event.joinCode)
        XCTAssertEqual(decoded?.colorway, .candy)
    }

    func testDecodeRejectsNonPozeString() {
        XCTAssertNil(EventInvite.decode(from: "https://example.com"))
        XCTAssertNil(EventInvite.decode(from: "poze://join/not-base64!!"))
    }

    func testJoinCodeIsStableAndDerivedFromID() {
        let id = UUID(uuidString: "A1B2C3D4-0000-0000-0000-000000000000")!
        let event = PozeEvent(id: id, name: "x", date: Date())
        XCTAssertEqual(event.joinCode, "A1B2C3")
        // Idempotent : même id → même code.
        XCTAssertEqual(event.joinCode, PozeEvent(id: id, name: "y", date: Date()).joinCode)
    }

    func testColorwayRawValuesAreStable() {
        // Ces rawValues sont persistées (groupes/events) : ne pas les casser.
        XCTAssertEqual(Colorway.aurora.rawValue, "aurora")
        XCTAssertEqual(Colorway.sunset.rawValue, "sunset")
        XCTAssertEqual(Colorway.allCases.count, 6)
    }
}
