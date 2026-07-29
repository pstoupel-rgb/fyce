import Foundation

/// Un event de l'écran d'accueil (soirée, mariage, vacances…). Comme un groupe,
/// il porte une liste de membres — scanner l'event cherche ces personnes dans ta
/// pellicule — mais avec une date, pour retrouver « qui était là ce soir-là ».
struct PozeEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var date: Date
    var colorway: Colorway
    var memberIDs: [UUID]
    var symbol: String

    init(id: UUID = UUID(),
         name: String,
         date: Date,
         colorway: Colorway = .sunset,
         memberIDs: [UUID] = [],
         symbol: String = "party.popper.fill") {
        self.id = id
        self.name = name
        self.date = date
        self.colorway = colorway
        self.memberIDs = memberIDs
        self.symbol = symbol
    }
}
