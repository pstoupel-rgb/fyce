import Foundation

extension String {
    /// Renvoie `nil` si la chaîne est vide, sinon la chaîne elle-même.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
