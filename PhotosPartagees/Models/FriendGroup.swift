import Foundation

/// Un groupe personnalisable de l'écran d'accueil (Famille, Potes, Boulot…).
/// Il rassemble plusieurs amis : scanner le groupe cherche n'importe lequel de
/// ses membres en une seule passe.
struct FriendGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorway: Colorway
    var memberIDs: [UUID]
    /// Symbole SF affiché sur la tuile (ex. "house.fill", "party.popper").
    var symbol: String

    init(id: UUID = UUID(),
         name: String,
         colorway: Colorway = .aurora,
         memberIDs: [UUID] = [],
         symbol: String = "person.2.fill") {
        self.id = id
        self.name = name
        self.colorway = colorway
        self.memberIDs = memberIDs
        self.symbol = symbol
    }
}
