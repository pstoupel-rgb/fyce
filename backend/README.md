# Poze — Backend (Supabase)

Fondation backend pour passer du prototype local au **multi-utilisateur réel** :
comptes, events, photos, et l'économie de **troc** (révélations).

> ⚠️ **État : fondation.** Le schéma SQL et la logique serveur ci-dessous sont
> réels et corrects, mais **non branchés/testés** contre une base live (à faire
> dans ton projet Supabase). L'app web actuelle tourne encore en **local**
> (localStorage) ; ce dossier est l'étape d'intégration suivante.

## Mise en place

1. Crée un projet sur [supabase.com](https://supabase.com).
2. SQL Editor → colle **`backend/schema.sql`** → Run.
3. Crée un bucket Storage `event-photos` (privé).
4. Active l'auth (email/OTP ou OAuth).
5. Récupère `Project URL` + clé `anon` → à mettre dans `web/config.js`.

## Modèle de données

| Table | Rôle |
|---|---|
| `profiles` | Comptes (1 par utilisateur) |
| `face_prints` | Empreinte de visage — **optionnel & sensible** (préférer l'on-device) |
| `events`, `event_members` | Events et leurs participants |
| `photos` | Photos d'un event (chemin Storage) |
| `photo_faces` | Visages reconnus rattachés (avec **consentement**) à un utilisateur |
| `reveals` | Développements (photo passée en HD) |
| `wallet_ledger` | **Le troc** : registre append-only des `+/−` ; solde = somme |
| `purchases` | Raccourci payant (crédité après paiement confirmé) |

Le **solde** se lit via la vue `wallet_balance`.

## Sécurité — le principe clé

**Toute la logique de gain/dépense est côté serveur**, jamais côté client :

- `develop_photo(photo_id)` → vérifie l'appartenance à l'event et le solde,
  **débite 1** de façon atomique, applique la **réciprocité** (+1 aux personnes
  présentes et consentantes), et renvoie le chemin du HD. Idempotent.
- `grant_reveals(user, amount, reason)` → à appeler depuis une **edge function**
  qui applique les **plafonds anti-abus** (voir `docs/troc-anti-abus.md`).
- Trigger `welcome` → +1 à la création du profil.

Les tables `wallet_ledger` / `reveals` / `purchases` sont en **lecture seule**
via RLS ; on n'y écrit que par ces fonctions `SECURITY DEFINER`.

## Reste à faire pour la prod

- [ ] Brancher l'app web sur Supabase (auth + lecture events/photos + appel RPC `develop_photo`).
- [ ] **Edge functions** : crédit des contributions (partage/réciprocité) avec plafonds ; webhook paiement (Stripe) pour créditer `purchases`.
- [ ] Upload des photos d'event par l'organisateur (rôle + policy dédiés).
- [ ] Génération d'URL signées pour le HD après `develop_photo`.
- [ ] Appliquer les règles de `docs/troc-anti-abus.md` (caps, dégressif, anti-self-troc).
- [ ] Cadrage RGPD (biométrie) avant mise en ligne.
