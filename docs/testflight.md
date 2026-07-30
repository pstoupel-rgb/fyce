# Mettre Poze sur TestFlight — guide pas-à-pas

Objectif : du repo → une build installable par tes testeurs via TestFlight.
Compte ~1–2 h la première fois (+ un petit passage de debug au premier build).

> Prérequis absolus : **un Mac**, **Xcode 15+**, un **compte Apple Developer
> Program** (99 $/an). Impossible depuis Linux/web — il faut compiler sur macOS.

---

## 0. Installer les outils

```bash
xcode-select --install            # outils ligne de commande
brew install xcodegen             # génère le projet Xcode depuis project.yml
```

## 1. Récupérer le code et générer le projet

```bash
git clone <ton-remote> poze && cd poze
git checkout claude/kind-fermat-pw62al
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # laisse les valeurs par défaut si pas de backend
xcodegen generate
open PhotosPartagees.xcodeproj
```

## 2. Signing & Capabilities (dans Xcode)

Cible **PhotosPartagees** → onglet **Signing & Capabilities** :

1. Coche **Automatically manage signing**.
2. **Team** = ton équipe Apple Developer.
3. **Bundle Identifier** : `com.photospartagees.app` (ou le tien — dois être unique).
   Si tu le changes, adapte aussi `PRODUCT_BUNDLE_IDENTIFIER` dans `project.yml`.
4. Vérifie que ces capabilities sont présentes (déjà dans les entitlements) :
   - **Push Notifications**
   - **Sign in with Apple**
   Xcode crée les profils de provisioning automatiquement.

## 3. Premier build (attends-toi à quelques ajustements)

- Sélectionne un **simulateur iPhone** → `Cmd+R`. Le code a été relu (plusieurs
  passes, 0 erreur trouvée) mais **jamais compilé** → prévois 1–3 corrections
  réelles au premier build (imports, API mineures). Normal, ça se règle vite.
- Puis teste sur un **vrai iPhone** (branché, sélectionné comme destination).

### Ce qui marche sans rien configurer
- **Mode invité** (Connexion → « Continuer sans compte »).
- Onglet **Moi** : ajouter ton visage, scanner ta pellicule, trier au swipe.
- **Amis / groupes / events** en local, tag manuel de visages, moment magique.
- **Sign in with Apple** (natif).

### Ce qui nécessite une config (facultatif pour TestFlight)
- **Google/Facebook, email, notif magique, mode event cloud, achats** → backend
  Supabase + comptes providers. Voir `auth-setup.md`, `backend-events.md`,
  `event-photographe.md`, `paiements.md`. L'app reste installable sans.

## 4. Reconnaissance faciale (précision)

Par défaut : repli **Vision** (ça marche). Pour la précision max, ajoute un modèle
Core ML — voir `coreml-face.md`. Pas nécessaire pour une première TestFlight.

## 5. App Store Connect — créer la fiche

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → +**.
2. Plateforme iOS, nom (« Poze » ou variante libre), langue, **Bundle ID** = celui
   de l'étape 2, SKU au choix.
3. **App Privacy** : remplis le questionnaire. Notre cas :
   - **Données collectées** : aucune si mode local. Si tu actives le backend,
     déclare a minima *Identifiants* (email/compte) et *Contenu utilisateur*
     (photos partagées) — usage « fonctionnalité de l'app », **pas** de tracking.
   - **Tracking : non.** (cohérent avec `PrivacyInfo.xcprivacy`.)
   - **URL de politique de confidentialité** : héberge `docs/privacy-policy.html`
     (GitHub Pages par ex.) et colle l'URL.

## 6. (Si tu vends des reveals) Achats intégrés

- App Store Connect → ton app → **Achats intégrés** → crée 3 **Consommables** avec
  exactement ces IDs :
  `com.photospartagees.app.reveals10 / reveals30 / reveals100`.
- Pour tester en local sans ça : Scheme → **Run → Options → StoreKit Configuration
  = `Configuration/Poze.storekit`**.
- Détails : `paiements.md`. (Non requis pour une première TestFlight.)

## 7. Archiver et envoyer

1. Destination = **Any iOS Device (arm64)**.
2. Menu **Product → Archive**.
3. Dans **Organizer** (fenêtre qui s'ouvre) → **Distribute App → App Store Connect
   → Upload**. Laisse les options par défaut (signing automatique).
4. Attends le traitement (quelques minutes à ~1 h) — tu reçois un mail.

> **Conformité chiffrement** : `ITSAppUsesNonExemptEncryption = false` est déjà
> dans l'Info.plist (on n'utilise que du chiffrement standard : HTTPS, Keychain,
> AES CryptoKit local) → pas de question à chaque build. Vérifie que ça colle à ton
> cas ; sinon, retire la clé et réponds au prompt.

## 8. TestFlight

1. App Store Connect → ton app → onglet **TestFlight**.
2. La build apparaît une fois traitée.
3. **Testeurs internes** (jusqu'à 100, membres de ton équipe) : dispo tout de suite,
   pas de revue.
4. **Testeurs externes** (jusqu'à 10 000, par email/lien public) : nécessite une
   **revue TestFlight** rapide (souvent < 24 h) + remplir « informations de test ».
5. Les testeurs installent l'app **TestFlight** et rejoignent via ton lien.

## Checklist express

- [ ] Xcode + compte développeur + `xcodegen generate`
- [ ] Signing auto, Team, Bundle ID unique, capabilities Push + Sign in with Apple
- [ ] Build simulateur OK (corrige le premier build) puis iPhone réel
- [ ] Fiche App Store Connect + App Privacy + URL politique de confidentialité
- [ ] (option) Produits IAP créés · (option) backend Supabase configuré
- [ ] Product → Archive → Upload
- [ ] TestFlight → ajouter testeurs → envoyer le lien

## Pièges fréquents

- **« No account for team »** → connecte ton Apple ID dans Xcode → Settings → Accounts.
- **Bundle ID déjà pris** → change-le (doit être unique sur tout l'App Store).
- **Icône manquante** → déjà fournie (`Assets.xcassets/AppIcon`, 1024 opaque).
- **Build rejetée pour « missing privacy policy »** → renseigne l'URL (étape 5).
- **Push ne marche pas en TestFlight** → normal sans clé APNs backend ; le reste
  fonctionne. Voir `notif-magique.md`.
