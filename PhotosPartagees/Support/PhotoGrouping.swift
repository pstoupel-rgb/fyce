import Foundation

/// Regroupement d'éléments par mois, du plus récent au plus ancien.
/// Fonction pure (sans dépendance UI ni PhotoKit) → testable unitairement.
enum PhotoGrouping {

    struct Section<Item>: Identifiable {
        let id: Date            // premier jour du mois
        let title: String
        let items: [Item]
    }

    static func sections<Item>(
        _ items: [Item],
        date: (Item) -> Date?,
        calendar: Calendar = .current,
        formatter: DateFormatter = PhotoGrouping.monthFormatter
    ) -> [Section<Item>] {
        let grouped = Dictionary(grouping: items) { item -> Date in
            let value = date(item) ?? .distantPast
            let comps = calendar.dateComponents([.year, .month], from: value)
            return calendar.date(from: comps) ?? .distantPast
        }
        return grouped.keys.sorted(by: >).map { key in
            let sorted = grouped[key]!.sorted {
                (date($0) ?? .distantPast) > (date($1) ?? .distantPast)
            }
            return Section(id: key, title: formatter.string(from: key), items: sorted)
        }
    }

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
