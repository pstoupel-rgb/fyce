import Foundation

/// Charge utile encodée dans un QR code pour rejoindre un event.
///
/// On y met les infos d'affichage (nom, date, couleur, symbole) + le code de
/// jointure — pas les empreintes de visage des membres (trop volumineuses pour un
/// QR). Celui qui scanne recrée l'event localement ; la synchro des membres/photos
/// se fera via le backend le jour où il est branché (`joinCode`).
struct EventInvite: Codable {
    let id: UUID
    let name: String
    let date: Date
    let colorway: Colorway
    let symbol: String
    let code: String

    /// Préfixe reconnaissable — le contenu qui suit est du JSON en base64.
    static let scheme = "poze://join/"

    init(event: PozeEvent) {
        self.id = event.id
        self.name = event.name
        self.date = event.date
        self.colorway = event.colorway
        self.symbol = event.symbol
        self.code = event.joinCode
    }

    /// La chaîne à encoder dans le QR : `poze://join/<base64(json)>`.
    func encoded() -> String {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        return Self.scheme + data.base64EncodedString()
    }

    /// Décode une chaîne scannée. `nil` si ce n'est pas une invitation Poze.
    static func decode(from string: String) -> EventInvite? {
        guard string.hasPrefix(scheme) else { return nil }
        let b64 = String(string.dropFirst(scheme.count))
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(EventInvite.self, from: data)
    }

    /// Reconstruit un event local (sans membres — l'utilisateur ajoutera les siens).
    func toEvent() -> PozeEvent {
        PozeEvent(id: id, name: name, date: date, colorway: colorway,
                  memberIDs: [], symbol: symbol)
    }
}
