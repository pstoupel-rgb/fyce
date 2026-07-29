import Foundation
import StoreKit

/// Achats intégrés (StoreKit 2) : packs de « reveals » (consommables). C'est la
/// voie **in-app** exigée par Apple pour du contenu numérique — Apple Pay y est
/// intégré. Pour Bancontact / carte, voir le checkout web (docs/paiements.md).
///
/// Les product IDs doivent exister dans App Store Connect (ou dans le fichier
/// `Configuration/Poze.storekit` pour tester en local).
@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false

    static let productIDs = [
        "com.photospartagees.app.reveals10",
        "com.photospartagees.app.reveals30",
        "com.photospartagees.app.reveals100"
    ]

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    /// Achète un pack ; crédite le portefeuille en cas de succès vérifié.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    Wallet.shared.credit(forProductID: product.id)
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
}
