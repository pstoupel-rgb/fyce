# Paiements — reveals (Apple + web) et B2B

Modèle : on vend des **reveals** (1 reveal = 1 photo développée/téléchargée). L'achat
est **par photo choisie** (tu sélectionnes les 5 photos que tu veux sur 1000, pas
tout), donc le nombre de reveals dépensés = le nombre de photos développées.

## La règle Apple (à connaître absolument)

- Tout ce qui se **consomme dans l'app** (reveals numériques) → **doit** passer par
  l'**achat intégré StoreKit** (Apple prend 15–30 %). Apple Pay y est déjà intégré.
- **Interdit** de mettre Stripe/Bancontact/carte *dans l'app* pour du numérique.
- Bancontact / carte / Apple Pay « classiques » servent sur le **web** (ou pour du
  physique / B2B).

## 1. In-app (StoreKit) — déjà codé

- `StoreService` (StoreKit 2) charge les packs et gère l'achat ; `Wallet` crédite le
  solde. `PaywallView` = la boutique. Sélection + dépense : `EventCloudView`.
- Product IDs : `com.photospartagees.app.reveals10 / reveals30 / reveals100`.
- **Test local** sans App Store Connect : `Configuration/Poze.storekit` — dans Xcode,
  Scheme → Run → Options → **StoreKit Configuration = Poze.storekit**.
- **Prod** : crée les 3 produits (Consommables) dans **App Store Connect** avec les
  mêmes IDs.

## 2. Web (Mollie) — meilleures marges, tous les moyens de paiement

Pour **Bancontact, carte, Apple Pay, iDEAL** avec des frais bien plus bas qu'Apple :

- `web/checkout.html` : la page boutique.
- `backend/functions/create-payment/` : crée un paiement Mollie et renvoie l'URL de
  redirection.
- À ajouter : `mollie-webhook` qui, sur paiement `paid`, crédite `wallet_ledger`
  (`delta = reveals`, `reason = 'purchase'`) pour l'utilisateur.
- Secrets : `supabase secrets set MOLLIE_API_KEY=live_xxx PUBLIC_SITE_URL=https://poze.app`.

> **DMA / EU** : depuis 2024 tu peux, dans l'UE, renvoyer vers un achat web externe
> depuis l'app (entitlement « External Purchase Link »). Sinon, garde le lien web
> hors des écrans d'achat in-app pour respecter les règles.

## 3. B2B (organisateurs)

Un organisateur d'event paie pour débloquer/partager l'album à ses invités →
**facture Stripe/Mollie**, aucun passage par Apple.

## Où en est le code

- **Fait & testable** : StoreService, Wallet, PaywallView, sélection + dépense par
  photo (`EventCloudView`), fichier `.storekit` de test.
- **Prêt à brancher (non testé live)** : `create-payment` (Mollie), `checkout.html`.
  Nécessite un compte **Mollie** + les produits **App Store Connect**.
