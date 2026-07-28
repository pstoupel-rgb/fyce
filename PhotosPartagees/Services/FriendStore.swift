import Foundation
import Vision
import UIKit
import os

/// Persiste les amis (nom, empreinte de visage, miniature) et, par ami, les
/// photos déjà partagées ou passées afin de ne pas les reproposer.
///
/// L'empreinte `VNFeaturePrintObservation` et `UIImage` conforment à
/// `NSSecureCoding` : on les archive en `Data` et on stocke le tout dans
/// `UserDefaults`. Tout reste on-device.
@MainActor
final class FriendStore: ObservableObject {

    @Published private(set) var friends: [Friend] = []

    private let defaults: UserDefaults
    private let friendsKey = "friends_v1"
    private let sharedKeyPrefix = "friend_shared_"   // + friendID
    private let skippedKeyPrefix = "friend_skipped_"  // + friendID

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFriends()
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
        defaults.removeObject(forKey: sharedKeyPrefix + friend.id.uuidString)
        defaults.removeObject(forKey: skippedKeyPrefix + friend.id.uuidString)
        persistFriends()
    }

    // MARK: - Historique par ami

    func sharedIDs(for friend: Friend) -> Set<String> {
        Set(defaults.stringArray(forKey: sharedKeyPrefix + friend.id.uuidString) ?? [])
    }

    func skippedIDs(for friend: Friend) -> Set<String> {
        Set(defaults.stringArray(forKey: skippedKeyPrefix + friend.id.uuidString) ?? [])
    }

    func markShared(_ photoID: String, for friend: Friend) {
        var set = sharedIDs(for: friend)
        guard set.insert(photoID).inserted else { return }
        defaults.set(Array(set), forKey: sharedKeyPrefix + friend.id.uuidString)
    }

    func markSkipped(_ photoID: String, for friend: Friend) {
        var set = skippedIDs(for: friend)
        guard set.insert(photoID).inserted else { return }
        defaults.set(Array(set), forKey: skippedKeyPrefix + friend.id.uuidString)
    }

    func resetHistory(for friend: Friend) {
        defaults.removeObject(forKey: sharedKeyPrefix + friend.id.uuidString)
        defaults.removeObject(forKey: skippedKeyPrefix + friend.id.uuidString)
    }

    // MARK: - Archivage

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
                "print": printData
            ]
            if let thumb = friend.thumbnail, let jpeg = thumb.jpegData(compressionQuality: 0.8) {
                dict["thumb"] = jpeg
            }
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
                                       VNFeaturePrintObservation.self]
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
            return Friend(id: id, name: name, referencePrint: print, thumbnail: thumb)
        } catch {
            Logger.app.error("Échec lecture ami : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
