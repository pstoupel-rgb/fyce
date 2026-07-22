# Poze — Backend (Supabase)

Backend multi-utilisateur : comptes, events partagés, upload, troc (révélations),
notifications, parrainage. C'est ce qui transforme le prototype local en vrai produit.

> **État : code complet, à brancher.** Le schéma (`schema.sql`) et le client
> (`web/backend.js`) sont réels et prêts, mais **non testés en live** ici : il faut
> ton projet Supabase. Tant que `web/config.js` n'est pas rempli, l'app reste en
> **mode local** (localStorage) — rien ne casse.

## Mise en place (≈ 15 min)

1. Crée un projet sur [supabase.com](https://supabase.com).
2. **SQL Editor** → colle **`backend/schema.sql`** → **Run**.
3. **Storage** → crée un bucket **privé** nommé **`event-photos`**.
4. **Authentication → Providers** → active **Anonymous sign-ins** (pour démarrer sans friction).
   *(Pour la prod : email OTP / OAuth à la place.)*
5. **Project Settings → API** → copie `Project URL` + clé `anon`.
6. Renseigne **`web/config.js`** :
   ```js
   window.SUPABASE_CONFIG = {
     url: "https://<ref>.supabase.co",
     anonKey: "<clé anon>",
     bucket: "event-photos",
   };
   ```
7. Recharge l'app → elle passe en **mode backend**.

## Ce que fait le client (`web/backend.js`)

| Méthode | Rôle |
|---|---|
| `signIn()` / `ensureProfile(name)` | Auth (anonyme) + profil |
| `walletBalance()` | Solde de révélations (vue `wallet_balance`) |
| `listEvents()` / `joinEvent(code)` / `createEvent(...)` | Events + jointure par QR/lien |
| `uploadPhotos(eventId, files)` | Upload Storage + lignes `photos` (hand-pick) |
| `eventPhotos(eventId)` | Les photos d'un event |
| `tagFace(photoId, userId)` | Rattache un visage reconnu (matching **on-device**) + consentement |
| `developPhoto(photoId)` | RPC atomique : débite 1, récompense, renvoie l'**URL signée HD** |
| `notifications()` / `markSeen(id)` | La « notif magique » |

## Sécurité — le principe

Toute la logique de gain/dépense est **côté serveur** (`SECURITY DEFINER`), jamais
côté client :
- `develop_photo` débite 1 révélation, crédite la **réciprocité** (+1 aux personnes
  présentes) **et l'uploader** (+1) — le moteur du supply — puis renvoie le HD.
- `join_event`, `credit_referral`, trigger `welcome` : idem serveur.
- Les tables `wallet_ledger` / `reveals` / `purchases` sont **lecture seule** via RLS.

## Reste à faire pour la prod

- [ ] **Brancher l'app** : remplacer le mode local par les appels `Backend.*`
      (events depuis `listEvents`, développer via `developPhoto`, etc.).
- [ ] **Edge functions** : plafonds anti-abus (voir `docs/troc-anti-abus.md`),
      notif push, webhook paiement (Stripe) pour créditer `purchases`.
- [ ] **Auth prod** : email/OAuth au lieu d'anonyme.
- [ ] **Reconnaissance** : garder le matching **on-device**, n'envoyer que les
      `photo_faces` consentis (jamais l'empreinte brute).
- [ ] **RGPD / mineurs** : cadrage juridique avant lancement.
