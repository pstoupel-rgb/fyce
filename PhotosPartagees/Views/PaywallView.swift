import SwiftUI
import StoreKit

/// Boutique de reveals. Paiement **Apple** (StoreKit) intégré ; un renvoi vers le
/// checkout web (Bancontact, carte, Apple Pay) pour de meilleures marges.
struct PaywallView: View {
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var wallet = Wallet.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busyID: String?

    /// URL de checkout web (à héberger — voir docs/paiements.md).
    private let webCheckout = URL(string: "https://poze.app/boutique")

    var body: some View {
        NavigationStack {
            ZStack {
                HaloBackground()
                VStack(spacing: 18) {
                    header
                    if store.isLoading {
                        ProgressView().tint(Theme.txt).frame(maxHeight: .infinity)
                    } else if store.products.isEmpty {
                        unavailable
                    } else {
                        packs
                    }
                    webNote
                }
                .padding(20)
            }
            .navigationTitle("Reveals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .task { await store.loadProducts() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ApertureMark(color: Theme.txt).frame(width: 60, height: 60)
            Text("\(wallet.reveals) reveals")
                .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Theme.txt)
            Text("1 reveal = 1 photo développée. Tu peux aussi en gagner en partageant.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var packs: some View {
        VStack(spacing: 12) {
            ForEach(store.products, id: \.id) { product in
                Button {
                    Task { busyID = product.id; _ = await store.purchase(product); busyID = nil }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Wallet.reveals(forProductID: product.id)) reveals")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text(product.displayName).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if busyID == product.id {
                            ProgressView().tint(.black).frame(width: 76)
                        } else {
                            Text(product.displayPrice)
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                                .frame(minWidth: 76).padding(.vertical, 9)
                                .background(Theme.txt, in: Capsule())
                        }
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(busyID != nil)
            }
        }
    }

    private var unavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart.badge.questionmark").font(.system(size: 36)).foregroundStyle(Theme.muted2)
            Text("Boutique indisponible").font(.headline).foregroundStyle(Theme.txt)
            Text("Configure les produits dans App Store Connect (ou le fichier Poze.storekit pour tester).")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var webNote: some View {
        if let webCheckout {
            Link(destination: webCheckout) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Payer autrement (Bancontact, carte) sur le web")
                }
                .font(.footnote).foregroundStyle(Theme.muted)
            }
        }
    }
}
