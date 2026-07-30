# PhotosPartagees

Application iOS native (SwiftUI, iOS 16+) qui :

1. **Scanne la photothèque** locale via PhotoKit.
2. **Détecte ton visage** avec Vision (détection + feature print comparé à un visage de référence).
3. Te laisse **valider/sélectionner** les photos matchées (aperçu plein écran, regroupement par mois).
4. **Upload la sélection** vers Supabase Storage et te fournit des **liens de partage signés**.

> ⚠️ Le matching repose sur `VNGenerateImageFeaturePrintRequest` appliqué au
> visage recadré — bon point de départ, remplaçable par un modèle Core ML de
> reconnaissance faciale dédié (FaceNet/ArcFace) pour plus de précision.

## Poze — l'app complète

Au-delà du scan « mon visage » d'origine, l'app (marque **Poze**) couvre :

- **Onboarding** au premier lancement (confidentialité on-device mise en avant).
- **Connexion** : Apple (natif), Google/Facebook (Supabase OAuth), compte email,
  ou **mode invité** local. Voir `docs/auth-setup.md`.
- **Accueil configurable** (design sobre « éditorial ») : **groupes** (Famille,
  Potes…) et **events** que tu crées, plus tes **amis** en accès rapide.
- **Amis / groupes / events** : sélectionne un sujet → scan on-device de la
  pellicule → **revue façon Tinder** (swipe droite = garder, gauche = passer, bas
  = supprimer réellement) + onglet « Partagées » avec envoi natif.
- **Scan multi-visages** : un groupe/event cherche *n'importe lequel* de ses
  membres en une passe.
- **Events par QR** : génère un QR pour inviter, scanne-en un pour rejoindre
  (`docs/backend-events.md`).
- **Partage cloud des photos d'event** (optionnel, Supabase) : push/pull des
  photos entre membres.
- **Protection des mineurs** : ajouter un mineur exige un **consentement parental**.

> Reconnaissance faciale **100 % on-device** (Vision). Aucune empreinte de visage
> n'est envoyée au serveur — seulement les photos que tu choisis de partager.

Backend et connexion sont **optionnels et gardés** : sans clés Supabase, l'app
fonctionne intégralement en local (mode invité).

## Architecture

Découpage **MVVM** + **injection de dépendances** (chaque service est derrière un
protocole, ce qui rend le `ScanViewModel` testable et le scan mockable).

```
PhotosPartagees/
├── App/                # Point d'entrée + Info.plist
├── Configuration/      # SupabaseConfig (lu depuis xcconfig) + SupabaseConfiguration
├── Models/             # PhotoAsset, MatchedPhoto, ScanState, UploadSummary
├── Services/           # Protocols + PhotoKit / Vision / Supabase / FaceScanner / Store
├── Support/            # AppLogger (os.Logger), PhotoGrouping (pur, testable)
├── ViewModels/         # ScanViewModel
└── Views/              # ContentView, ScanView, SettingsView, PhotoGridView, …
PhotosPartageesTests/   # Tests unitaires (XCTest)
Config/                 # Secrets.example.xcconfig (le vrai Secrets.xcconfig est ignoré)
.github/workflows/      # CI (build + test + SwiftLint)
```

| Couche | Protocole | Implémentation |
|--------|-----------|----------------|
| Photothèque | `PhotoLibraryProviding` | `PhotoLibraryService` (PhotoKit) |
| Détection | `FaceDetecting` | `FaceDetectionService` (Vision) |
| Matching | `FaceMatching` | `FaceMatcher` (distance de feature prints) |
| Upload/partage | `PhotoUploading` | `SupabaseService` (REST + URL signées) |
| Persistance | `SharedPhotosStoring` | `SharedPhotosStore` (UserDefaults) |

### Points techniques

- **Scan parallélisé hors main thread** : `FaceScanner` analyse les photos par lots
  via `withTaskGroup` (concurrence bornée), l'UI reste fluide ; le `ScanViewModel`
  (`@MainActor`) ne fait que publier la progression et les résultats.
- **Validation utilisateur** : sélection/désélection, aperçu plein écran, *Tout*/*Aucune*.
- **Persistance** : les photos déjà partagées sont mémorisées et non reproposées.
- **Récap de partage** : succès/échecs, relance des échecs, **copie des liens signés**.
- **Logging** : `os.Logger` (catégories `scan`, `upload`, `vision`).

## Prérequis

- Xcode 15+, iOS 16+
- [XcodeGen](https://github.com/yonyz/XcodeGen) : `brew install xcodegen`

## Configuration

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# édite Config/Secrets.xcconfig :
#   SUPABASE_HOST      = abcdxyz.supabase.co      (sans https://)
#   SUPABASE_ANON_KEY  = <clé anon>
#   SUPABASE_BUCKET    = shared-photos
```

`Config/Secrets.xcconfig` est **gitignoré**. Les valeurs sont injectées dans
l'`Info.plist` et lues au runtime par `SupabaseConfig`.

> Ne committe jamais une clé `service_role`. Utilise la clé `anon` + RLS, ou un
> endpoint d'upload signé côté serveur.

## Générer et lancer

```bash
xcodegen generate
open PhotosPartagees.xcodeproj
```

## Tests

```bash
xcodebuild test \
  -project PhotosPartagees.xcodeproj \
  -scheme PhotosPartagees \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

Couverts : `PhotoGrouping` (regroupement par date), `SharedPhotosStore`
(persistance), `SupabaseService` (upload/erreurs/URL signées via `URLProtocol`
mocké), `FaceMatcher` (état sans référence).

## CI

`.github/workflows/ci.yml` génère le projet, exécute les tests sur simulateur et
lance SwiftLint à chaque push/PR.

## Permissions

`Info.plist` déclare : `NSPhotoLibraryUsageDescription` (scan + suppression),
`NSPhotoLibraryAddUsageDescription` (enregistrer une photo d'event),
`NSCameraUsageDescription` (scan d'un QR d'event). Le scheme d'URL `poze` (OAuth)
est déclaré via `CFBundleURLTypes`, et l'entitlement *Sign in with Apple* est actif.

## Sécurité & confidentialité (la confiance comme produit)

- **Empreintes de visage chiffrées au repos** : AES-GCM (`CryptoBox`) avec une clé
  256 bits dans le Keychain. La biométrie n'est jamais en clair sur le disque.
- **Verrou Face ID / code** optionnel (`AppLockService`, `LocalAuthentication`).
- **Centre de confidentialité** (`PrivacyCenterView`) : transparence sur ce qui est
  stocké, **export de portabilité** (métadonnées, jamais d'empreinte), et
  **droit à l'oubli** en un tap (efface données locales + secrets Keychain).
- **Privacy Manifest Apple** (`PrivacyInfo.xcprivacy`) : zéro tracking, zéro
  collecte, raison d'usage `UserDefaults` déclarée.
- Jetons d'authentification dans le **Keychain** ; clé `anon` + RLS uniquement,
  jamais de `service_role`.
- Reconnaissance faciale **on-device** (Vision) ; consentement requis pour les mineurs.

## Documentation

- `docs/testflight.md` — **mettre l'app sur TestFlight, pas à pas.**
- `docs/coreml-face.md` — brancher un modèle Core ML (précision faciale).
- `docs/auth-setup.md` — providers de connexion (Apple/Google/Facebook/email).
- `docs/backend-events.md` — schéma, RLS, partage de photos d'event.
- `docs/event-photographe.md` — mode photographe (matching on-device).
- `docs/notif-magique.md` — la notif « X a de nouvelles photos de toi ».
- `docs/paiements.md` — reveals (StoreKit) + checkout web (Mollie).
- `docs/sharing-box.md` — impression brandée / téléchargement HD.
