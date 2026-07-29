import Foundation
import UIKit

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
    /// Identifiant de l'event côté serveur (Supabase), une fois créé/rejoint.
    /// `nil` en mode local. Permet de lier les photos partagées à cet event.
    var remoteID: String?
    /// Logo de l'event (JPEG/PNG compressé) — pour brander les impressions. Optionnel.
    var logoData: Data?

    init(id: UUID = UUID(),
         name: String,
         date: Date,
         colorway: Colorway = .sunset,
         memberIDs: [UUID] = [],
         symbol: String = "party.popper.fill",
         remoteID: String? = nil,
         logoData: Data? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.colorway = colorway
        self.memberIDs = memberIDs
        self.symbol = symbol
        self.remoteID = remoteID
        self.logoData = logoData
    }

    /// Logo prêt à afficher, s'il existe.
    var logoImage: UIImage? { logoData.flatMap(UIImage.init(data:)) }

    /// Code court, lisible et stable, dérivé de l'id — partagé via QR pour
    /// rejoindre l'event (ex. "A1B2C3").
    var joinCode: String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }
}
