import Foundation
import Vision
import UIKit
import os

/// Source de vérité locale de l'app : amis, groupes, events, et l'historique
/// « gardé / passé » par sujet de revue. Tout reste on-device.
///
/// - Les amis portent une empreinte `VNFeaturePrintObservation` + une miniature
///   `UIImage` : archivés via `NSSecureCoding`.
/// - Groupes et events sont de simples `Codable` : encodés en JSON.
@MainActor
final class FriendStore: ObservableObject, ReviewHistoryStoring {

    @Published private(set) var friends: [Friend] = []
    @Published private(set) var groups: [FriendGroup] = []
    @Published private(set) var events: [PozeEvent] = []

    private let defaults: UserDefaults
    // _v2 : les blobs sont désormais chiffrés au repos (AES-GCM). On ne relit pas
    // l'ancien format en clair — la biométrie ne doit jamais rester déchiffrable.
    private let friendsKey = "friends_v3"   // v3 : multi-références par ami
    private let groupsKey = "groups_v2"
    private let eventsKey = "events_v2"
    private let sharedKeyPrefix = "review_shared_"    // + historyKey
    private let skippedKeyPrefix = "review_skipped_"   // + historyKey

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFriends()
        loadGroups()
        loadEvents()
    }

    // MARK: - Amis

    func add(_ friend: Friend) {
        friends.append(friend)
        persistFriends()
    }

    func rename(_ friend: Friend, to name: String) {
        guard let idx = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        friends[idx].name = name
        persistFriends()
    }

    func remove(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        // Nettoie les références de cet ami dans les groupes/events.
        for i in groups.indices { groups[i].memberIDs.removeAll { $0 == friend.id } }
        for i in events.indices { events[i].memberIDs.removeAll { $0 == friend.id } }
        persistFriends(); persistGroups(); persistEvents()
        resetHistory(forKey: friend.id.uuidString)
    }

    func friend(withID id: UUID) -> Friend? { friends.first { $0.id == id } }

    /// Rattache un ami local à son compte serveur (quand il a rejoint via ton lien).
    /// Nécessaire pour que la « notif magique » cible la bonne personne.
    func link(_ friend: Friend, toUserID userID: String) {
        guard let idx = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        friends[idx].remoteUserID = userID
        persistFriends()
    }

    /// Ajoute une empreinte de référence à un ami (tagging manuel → l'app apprend).
    func addReference(_ print: VNFeaturePrintObservation, to friend: Friend) {
        guard let idx = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        friends[idx].addReference(print)
        persistFriends()
    }

    func members(ofIDs ids: [UUID]) -> [Friend] {
        ids.compactMap { id in friends.first { $0.id == id } }
    }

    // MARK: - Groupes

    func addOrUpdate(_ group: FriendGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx] = group
        } else {
            groups.append(group)
        }
        persistGroups()
    }

    func remove(_ group: FriendGroup) {
        groups.removeAll { $0.id == group.id }
        persistGroups()
        resetHistory(forKey: group.id.uuidString)
    }

    // MARK: - Events

    func addOrUpdate(_ event: PozeEvent) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
        persistEvents()
    }

    func remove(_ event: PozeEvent) {
        events.removeAll { $0.id == event.id }
        persistEvents()
        resetHistory(forKey: event.id.uuidString)
    }

    /// Mémorise l'identifiant serveur d'un event (après création/adhésion backend).
    func setRemoteID(_ remoteID: String, for event: PozeEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        guard events[idx].remoteID != remoteID else { return }
        events[idx].remoteID = remoteID
        persistEvents()
    }

    // MARK: - Historique par sujet (ReviewHistoryStoring)

    func sharedIDs(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: sharedKeyPrefix + key) ?? [])
    }

    func skippedIDs(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: skippedKeyPrefix + key) ?? [])
    }

    func markShared(_ photoID: String, forKey key: String) {
        var set = sharedIDs(forKey: key)
        guard set.insert(photoID).inserted else { return }
        defaults.set(Array(set), forKey: sharedKeyPrefix + key)
    }

    func markSkipped(_ photoID: String, forKey key: String) {
        var set = skippedIDs(forKey: key)
        guard set.insert(photoID).inserted else { return }
        defaults.set(Array(set), forKey: skippedKeyPrefix + key)
    }

    func resetHistory(forKey key: String) {
        defaults.removeObject(forKey: sharedKeyPrefix + key)
        defaults.removeObject(forKey: skippedKeyPrefix + key)
    }

    // MARK: - Confidentialité (transparence, export, droit à l'oubli)

    struct DataSummary {
        var friends: Int
        var groups: Int
        var events: Int
        var facePrints: Int      // une empreinte par ami
        var sharedRecords: Int   // photos marquées partagées (tous sujets)
    }

    func dataSummary() -> DataSummary {
        let shared = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(sharedKeyPrefix) }
            .reduce(0) { $0 + (defaults.stringArray(forKey: $1)?.count ?? 0) }
        return DataSummary(friends: friends.count, groups: groups.count, events: events.count,
                           facePrints: friends.count, sharedRecords: shared)
    }

    /// Export de portabilité — **métadonnées uniquement**, jamais d'empreinte de visage.
    func exportJSON() -> Data? {
        let iso = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "app": "Poze",
            "note": "Aucune empreinte de visage n'est exportée (biométrie strictement on-device).",
            "friends": friends.map { ["name": $0.name, "isMinor": $0.isMinor] },
            "groups": groups.map { ["name": $0.name, "members": $0.memberIDs.count] },
            "events": events.map { ["name": $0.name, "date": iso.string(from: $0.date)] }
        ]
        return try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    /// Droit à l'oubli : efface toutes les données locales + les secrets (Keychain).
    func wipeAll() {
        friends = []; groups = []; events = []
        let keys = defaults.dictionaryRepresentation().keys.filter {
            $0 == friendsKey || $0 == groupsKey || $0 == eventsKey ||
            $0.hasPrefix(sharedKeyPrefix) || $0.hasPrefix(skippedKeyPrefix)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        KeychainHelper.wipe()   // clé de chiffrement + jeton d'auth
        objectWillChange.send()
    }

    // MARK: - Persistance chiffrée (groupes / events)

    private func loadGroups() {
        guard let sealed = defaults.data(forKey: groupsKey),
              let data = CryptoBox.open(sealed) else { return }
        groups = (try? JSONDecoder().decode([FriendGroup].self, from: data)) ?? []
    }

    private func persistGroups() {
        guard let data = try? JSONEncoder().encode(groups),
              let sealed = CryptoBox.seal(data) else { return }
        defaults.set(sealed, forKey: groupsKey)
    }

    private func loadEvents() {
        guard let sealed = defaults.data(forKey: eventsKey),
              let data = CryptoBox.open(sealed) else { return }
        events = (try? JSONDecoder().decode([PozeEvent].self, from: data)) ?? []
    }

    private func persistEvents() {
        guard let data = try? JSONEncoder().encode(events),
              let sealed = CryptoBox.seal(data) else { return }
        defaults.set(sealed, forKey: eventsKey)
    }

    // MARK: - Archivage chiffré des amis (empreintes de visage = biométrie)

    private func loadFriends() {
        guard let sealed = defaults.data(forKey: friendsKey),
              let blob = CryptoBox.open(sealed),
              let raw = (try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSData.self], from: blob)) as? [Data]
        else { return }
        friends = raw.compactMap(decodeFriend)
    }

    private func persistFriends() {
        let raw = friends.compactMap(encodeFriend)   // [Data]
        guard let blob = try? NSKeyedArchiver.archivedData(
                withRootObject: raw, requiringSecureCoding: false),
              let sealed = CryptoBox.seal(blob) else { return }
        defaults.set(sealed, forKey: friendsKey)
    }

    private func encodeFriend(_ friend: Friend) -> Data? {
        do {
            // Toutes les empreintes de référence (multi-références).
            let printsData = try NSKeyedArchiver.archivedData(
                withRootObject: friend.referencePrints, requiringSecureCoding: true)
            var dict: [String: Any] = [
                "id": friend.id.uuidString,
                "name": friend.name,
                "prints": printsData,
                "isMinor": friend.isMinor,
                "parentalConsent": friend.parentalConsent
            ]
            if let thumb = friend.thumbnail, let jpeg = thumb.jpegData(compressionQuality: 0.8) {
                dict["thumb"] = jpeg
            }
            if let contact = friend.parentContact { dict["parentContact"] = contact }
            if let uid = friend.remoteUserID { dict["remoteUserID"] = uid }
            return try NSKeyedArchiver.archivedData(
                withRootObject: dict, requiringSecureCoding: false)
        } catch {
            Logger.app.error("Échec archivage ami : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func decodeFriend(_ data: Data) -> Friend? {
        do {
            let allowed: [AnyClass] = [NSDictionary.self, NSArray.self, NSString.self, NSData.self,
                                       NSNumber.self, VNFeaturePrintObservation.self]
            guard let dict = try NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: allowed, from: data) as? [String: Any],
                  let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = dict["name"] as? String,
                  let printsData = dict["prints"] as? Data,
                  let prints = try NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: [NSArray.self, VNFeaturePrintObservation.self],
                    from: printsData) as? [VNFeaturePrintObservation],
                  !prints.isEmpty
            else { return nil }

            var thumb: UIImage?
            if let thumbData = dict["thumb"] as? Data { thumb = UIImage(data: thumbData) }
            let isMinor = dict["isMinor"] as? Bool ?? false
            let consent = dict["parentalConsent"] as? Bool ?? false
            let contact = dict["parentContact"] as? String
            let remoteUID = dict["remoteUserID"] as? String
            return Friend(id: id, name: name, referencePrints: prints, thumbnail: thumb,
                          isMinor: isMinor, parentalConsent: consent, parentContact: contact,
                          remoteUserID: remoteUID)
        } catch {
            Logger.app.error("Échec lecture ami : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
