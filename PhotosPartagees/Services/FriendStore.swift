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
    private let friendsKey = "friends_v1"
    private let groupsKey = "groups_v1"
    private let eventsKey = "events_v1"
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

    // MARK: - Persistance JSON (groupes / events)

    private func loadGroups() {
        guard let data = defaults.data(forKey: groupsKey) else { return }
        groups = (try? JSONDecoder().decode([FriendGroup].self, from: data)) ?? []
    }

    private func persistGroups() {
        if let data = try? JSONEncoder().encode(groups) { defaults.set(data, forKey: groupsKey) }
    }

    private func loadEvents() {
        guard let data = defaults.data(forKey: eventsKey) else { return }
        events = (try? JSONDecoder().decode([PozeEvent].self, from: data)) ?? []
    }

    private func persistEvents() {
        if let data = try? JSONEncoder().encode(events) { defaults.set(data, forKey: eventsKey) }
    }

    // MARK: - Archivage des amis (NSSecureCoding)

    private func loadFriends() {
        guard let raw = defaults.array(forKey: friendsKey) as? [Data] else { return }
        friends = raw.compactMap(decodeFriend)
    }

    private func persistFriends() {
        let raw = friends.compactMap(encodeFriend)
        defaults.set(raw, forKey: friendsKey)
    }

    private func encodeFriend(_ friend: Friend) -> Data? {
        do {
            let printData = try NSKeyedArchiver.archivedData(
                withRootObject: friend.referencePrint, requiringSecureCoding: true)
            var dict: [String: Any] = [
                "id": friend.id.uuidString,
                "name": friend.name,
                "print": printData,
                "isMinor": friend.isMinor,
                "parentalConsent": friend.parentalConsent
            ]
            if let thumb = friend.thumbnail, let jpeg = thumb.jpegData(compressionQuality: 0.8) {
                dict["thumb"] = jpeg
            }
            if let contact = friend.parentContact { dict["parentContact"] = contact }
            return try NSKeyedArchiver.archivedData(
                withRootObject: dict, requiringSecureCoding: false)
        } catch {
            Logger.app.error("Échec archivage ami : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func decodeFriend(_ data: Data) -> Friend? {
        do {
            let allowed: [AnyClass] = [NSDictionary.self, NSString.self, NSData.self,
                                       NSNumber.self, VNFeaturePrintObservation.self]
            guard let dict = try NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: allowed, from: data) as? [String: Any],
                  let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = dict["name"] as? String,
                  let printData = dict["print"] as? Data,
                  let print = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: VNFeaturePrintObservation.self, from: printData)
            else { return nil }

            var thumb: UIImage?
            if let thumbData = dict["thumb"] as? Data { thumb = UIImage(data: thumbData) }
            let isMinor = dict["isMinor"] as? Bool ?? false
            let consent = dict["parentalConsent"] as? Bool ?? false
            let contact = dict["parentContact"] as? String
            return Friend(id: id, name: name, referencePrint: print, thumbnail: thumb,
                          isMinor: isMinor, parentalConsent: consent, parentContact: contact)
        } catch {
            Logger.app.error("Échec lecture ami : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
