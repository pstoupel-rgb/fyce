# Poze iOS — Notifications push (« nouvelles photos de toi »)

La notif push est **le superpouvoir du natif** : c'est ce qui fait revenir les gens.
Voici ce qui est **codé** et ce qu'il reste à faire (nécessite un **Mac + Xcode** et un
**compte Apple Developer à 99 $/an** — obligatoire pour APNs).

## Ce qui est déjà codé (dans le repo)

| Fichier | Rôle |
|---|---|
| `Support/PushNotificationManager.swift` | Demande la permission, s'enregistre à APNs, gère le token, affiche au 1er plan, + **notif locale de démo** |
| `Services/PushRegistrationService.swift` | Envoie le token APNs au backend (`device_tokens`) |
| `App/PhotosPartageesApp.swift` | AppDelegate : reçoit le token, lance la demande de permission |
| `App/PhotosPartagees.entitlements` | `aps-environment` (capacité Push) |
| `App/Info.plist` | `UIBackgroundModes = remote-notification` |
| `backend/schema.sql` | table `device_tokens` (RLS) |

## Tester SANS compte Apple (au simulateur, 2 min)
La **notif locale** marche sans APNs. Appelle quelque part (ex. un bouton de debug) :
```swift
PushNotificationManager.shared.scheduleMagicNotificationDemo(count: 3, eventName: "Le Duplex")
```
→ 5 s plus tard : *« 📸 3 new photos of you at Le Duplex »*. Tu vois exactement l'effet.

## Activer les VRAIES notifs push (prod — nécessite Mac + compte Apple)

1. **Apple Developer** (99 $/an) → crée un **App ID** avec la capacité **Push Notifications**.
2. Crée une **clé APNs** (`.p8`) dans *Certificates, Identifiers & Profiles → Keys* →
   note le **Key ID** et le **Team ID**.
3. Dans **Xcode** : cible → *Signing & Capabilities* → **+ Push Notifications**
   (l'entitlements est déjà là) + ton équipe de signature.
4. **Côté serveur (Supabase edge function)** : quand de nouvelles photos matchent un
   utilisateur, envoyer un push à ses `device_tokens` via APNs (avec la clé `.p8`).
   Squelette de l'edge function (Deno) :
   ```ts
   // supabase/functions/send-push/index.ts (à créer)
   // 1. lire device_tokens du user
   // 2. signer un JWT APNs (ES256, clé .p8, Key ID, Team ID)
   // 3. POST https://api.push.apple.com/3/device/<token>
   //    header apns-topic = com.photospartagees.app, body { aps:{ alert:{...}, sound:"default" } }
   ```
5. **Déclencheur** : sur insert dans `photo_faces` (un visage consenti matché) →
   appeler `send-push` pour créer la notif + le push.

## Rappels
- Le token APNs n'est délivré **que sur un vrai appareil** (pas le simulateur).
- Bundle ID à aligner partout : `com.photospartagees.app` (= `apns-topic`).
- Renomme le bundle en `com.poze.app` si tu veux quand tu créeras l'App ID.
- RGPD : la notif ne doit révéler que **tes** photos (pas d'info sur d'autres personnes).

## Générer & ouvrir le projet
```bash
brew install xcodegen && xcodegen generate && open PhotosPartagees.xcodeproj
```
