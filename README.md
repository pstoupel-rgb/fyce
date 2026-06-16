# PhotosPartagees

Application iOS native (SwiftUI) qui :

1. **Scanne la photothèque** locale via PhotoKit.
2. **Détecte ton visage** avec le framework Vision (détection de visage + empreinte/feature print et comparaison à un visage de référence).
3. **Upload les photos qui matchent** vers un bucket Supabase Storage.

> ⚠️ Cette base de projet pose l'architecture et le flux complet. Le matching de
> visage repose sur `VNGenerateImageFeaturePrintRequest` appliqué au visage
> recadré — c'est un bon point de départ, remplaçable par un modèle Core ML de
> reconnaissance faciale dédié (FaceNet/ArcFace) pour plus de précision.

## Architecture

```
PhotosPartagees/
├── App/                # Point d'entrée + Info.plist
├── Configuration/      # Config Supabase (URL, clé, bucket)
├── Models/             # Modèles de données
├── Services/           # PhotoKit, Vision, Supabase
├── ViewModels/         # Logique de présentation (MVVM)
└── Views/              # Écrans SwiftUI
```

| Couche | Fichier | Rôle |
|--------|---------|------|
| PhotoKit | `PhotoLibraryService.swift` | Autorisation + énumération des `PHAsset`, chargement des images |
| Vision | `FaceDetectionService.swift` | Détection de visages + génération de feature prints |
| Vision | `FaceMatcher.swift` | Empreinte de référence + comparaison de distance |
| Réseau | `SupabaseService.swift` | Upload vers Supabase Storage (REST) |
| MVVM | `ScanViewModel.swift` | Orchestration scan → match → upload |

## Prérequis

- Xcode 15+
- iOS 16+
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`) pour générer le projet

## Générer et ouvrir le projet

```bash
xcodegen generate
open PhotosPartagees.xcodeproj
```

> Sans XcodeGen, tu peux aussi créer un projet App SwiftUI dans Xcode et y
> glisser le dossier `PhotosPartagees/`.

## Configuration Supabase

1. Crée un bucket Storage (ex. `shared-photos`) dans ton projet Supabase.
2. Renseigne tes identifiants dans `PhotosPartagees/Configuration/SupabaseConfig.swift`
   (ou via les variables d'environnement / un fichier `Secrets.xcconfig` non commité).

```swift
static let url = URL(string: "https://<project-ref>.supabase.co")!
static let anonKey = "<ton-anon-ou-service-key>"
static let bucket = "shared-photos"
```

> Ne committe jamais une clé `service_role` dans un client. Pour de la prod,
> passe par un endpoint signé / RLS et la clé `anon`.

## Permissions

`Info.plist` déclare `NSPhotoLibraryUsageDescription` (lecture de la photothèque).

## Flux utilisateur

1. L'utilisateur choisit une **photo de référence** de son visage.
2. L'app scanne la photothèque, détecte les visages et compare au visage de référence.
3. Les photos matchées sont **regroupées par mois** et présentées pour validation.
4. L'utilisateur **sélectionne** (ou prévisualise en plein écran) les photos à partager.
5. Seule la sélection est **uploadée vers Supabase**, suivie d'un **récap** (succès / échecs).

## Fonctionnalités

- **Validation manuelle** : sélection/désélection des photos, aperçu plein écran, *Tout* / *Aucune*.
- **Regroupement par date** : les matchs sont triés par mois (`PhotoGridView`).
- **Persistance** : les photos déjà partagées sont mémorisées (`SharedPhotosStore`,
  `UserDefaults`) et marquées « déjà partagée » sans être reproposées au partage.
- **Récap de fin de partage** : `UploadSummaryView` indique succès/échecs avec
  un bouton **Réessayer les échecs**.
