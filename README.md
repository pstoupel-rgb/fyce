# PhotosPartagees

Application iOS native (SwiftUI, iOS 16+) qui :

1. **Scanne la photothèque** locale via PhotoKit.
2. **Détecte ton visage** avec Vision (détection + feature print comparé à un visage de référence).
3. Te laisse **valider/sélectionner** les photos matchées (aperçu plein écran, regroupement par mois).
4. **Upload la sélection** vers Supabase Storage et te fournit des **liens de partage signés**.

> ⚠️ Le matching repose sur `VNGenerateImageFeaturePrintRequest` appliqué au
> visage recadré — bon point de départ, remplaçable par un modèle Core ML de
> reconnaissance faciale dédié (FaceNet/ArcFace) pour plus de précision.

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

`Info.plist` déclare `NSPhotoLibraryUsageDescription`.
