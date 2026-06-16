import XCTest
@testable import PhotosPartagees

final class PhotoGroupingTests: XCTestCase {

    private struct Item {
        let date: Date?
    }

    private let calendar = Calendar(identifier: .gregorian)

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }

    func testGroupsByMonthMostRecentFirst() {
        let items = [
            Item(date: makeDate(2026, 5, 2)),
            Item(date: makeDate(2026, 6, 1)),
            Item(date: makeDate(2026, 6, 15))
        ]

        let sections = PhotoGrouping.sections(items, date: { $0.date }, calendar: calendar)

        XCTAssertEqual(sections.count, 2)
        // Le mois le plus récent (juin) vient en premier et contient 2 éléments.
        XCTAssertEqual(sections[0].items.count, 2)
        XCTAssertEqual(sections[1].items.count, 1)
    }

    func testItemsWithinSectionAreSortedDescending() {
        let items = [
            Item(date: makeDate(2026, 6, 1)),
            Item(date: makeDate(2026, 6, 15))
        ]

        let sections = PhotoGrouping.sections(items, date: { $0.date }, calendar: calendar)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.first?.date, makeDate(2026, 6, 15))
        XCTAssertEqual(sections[0].items.last?.date, makeDate(2026, 6, 1))
    }

    func testNilDatesAreGroupedTogether() {
        let items = [Item(date: nil), Item(date: nil)]
        let sections = PhotoGrouping.sections(items, date: { $0.date }, calendar: calendar)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.count, 2)
    }
}
