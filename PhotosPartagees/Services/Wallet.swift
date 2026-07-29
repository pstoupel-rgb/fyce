import Foundation
import SwiftUI

/// Portefeuille local de « reveals » (crédits pour développer/télécharger une photo
/// précise). Le solde est reflété localement ; en production il sera confirmé côté
/// serveur (`wallet_ledger`). 1 reveal = 1 photo développée.
@MainActor
final class Wallet: ObservableObject {
    static let shared = Wallet()

    @Published private(set) var reveals: Int
    private let key = "wallet_reveals_v1"

    init() {
        reveals = UserDefaults.standard.integer(forKey: key)
    }

    func credit(_ n: Int) {
        guard n > 0 else { return }
        reveals += n
        persist()
    }

    /// Crédite selon le pack acheté (déduit du product id).
    func credit(forProductID id: String) {
        credit(Self.reveals(forProductID: id))
    }

    /// Dépense `n` reveals si le solde suffit.
    @discardableResult
    func spend(_ n: Int) -> Bool {
        guard n > 0, reveals >= n else { return false }
        reveals -= n
        persist()
        return true
    }

    /// Gagné par contribution (troc) — partager une photo où un ami apparaît.
    func earnFromContribution(_ n: Int = 1) { credit(n) }

    static func reveals(forProductID id: String) -> Int {
        if id.contains("100") { return 100 }
        if id.contains("30") { return 30 }
        if id.contains("10") { return 10 }
        return 0
    }

    private func persist() {
        UserDefaults.standard.set(reveals, forKey: key)
    }
}
