import Foundation

/// Persiste localement les identifiants des photos déjà partagées afin de ne
/// pas les reproposer (ni les ré-uploader) lors des scans suivants.
final class SharedPhotosStore: SharedPhotosStoring {
    private let key = "shared_photo_ids"
    private let defaults: UserDefaults
    private(set) var sharedIDs: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sharedIDs = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func contains(_ id: String) -> Bool {
        sharedIDs.contains(id)
    }

    func markShared(_ id: String) {
        guard sharedIDs.insert(id).inserted else { return }
        persist()
    }

    /// Réinitialise l'historique (les photos pourront être reproposées).
    func reset() {
        sharedIDs.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(Array(sharedIDs), forKey: key)
    }
}
