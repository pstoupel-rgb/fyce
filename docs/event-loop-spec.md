# Poze — Spec du « loop d'event »

Le moteur de croissance : une boucle où **les photos entrent** (upload),
**les gens se retrouvent** (reconnaissance), **reviennent** (notif),
**paient/contribuent** (troc) et **ramènent leurs potes** (invitation).
Jamais d'auto-scan : tout upload est **choisi à la main**.

## 1. Les 3 rôles

| Rôle | Fait quoi | Motivation |
|---|---|---|
| **Organisateur** (club, promoteur, photographe) | Crée l'event, upload le lot officiel, obtient un QR/lien | Payé (B2B), engage sa foule |
| **Contributeur** (fêtard) | Ajoute *ses* photos de la soirée (choisies) | Gagne des révélations + statut « héros » |
| **Chercheur** (tout le monde) | Scanne son visage, retrouve ses photos, les développe | Récupère SES photos |

Une même personne est souvent les trois à la fois.

## 2. Le parcours, étape par étape

1. **Créer l'event** — l'organisateur crée « Le Duplex · sam. 14 ». Génère un
   **QR code + lien** (`poze.app/e/duplex-0614`).
2. **Rejoindre** — les gens scannent le QR (affiché en soirée) ou cliquent le lien
   → ils rejoignent l'event (et scannent leur visage si 1re fois).
3. **Uploader** — l'organisateur pousse le lot officiel ; les fêtards **ajoutent
   leurs photos** via un sélecteur (jamais toute la pellicule). Chaque photo est
   analysée **sur l'appareil**.
4. **Se retrouver** — pour chaque participant, l'app fait matcher son visage aux
   photos de l'event → ses **négatifs** apparaissent.
5. **Notif magique** — « 📸 3 nouvelles photos de toi au Duplex ». LA raison de revenir.
6. **Développer** — l'utilisateur dépense **1 révélation** pour passer un négatif en HD
   (ou raccourci payant).
7. **Récompenser l'upload** — quand une photo est **développée par un tiers**,
   celui qui l'a **uploadée** gagne **+1 révélation** (plafonné). L'upload devient rentable.
8. **Inviter les absents** — un visage détecté non-inscrit → l'organisateur/le posteur
   peut **inviter** (lien WhatsApp/mail). L'invité arrive avec un bonus, le parrain gagne.
   → retour à l'étape 2 : **la boucle tourne**.

## 3. Mécanique de récompense (troc) — valeurs de départ

| Action | Effet | Garde-fou |
|---|---|---|
| Rejoindre / scanner son visage | +1 (bienvenue) | 1 fois |
| Uploader des photos | **0 à l'upload** | Anti-spam |
| Ta photo est **développée par un tiers** | **+1** au posteur | Max ~10/jour, dégressif |
| Développer un négatif | −1 | idempotent |
| Inviter → invité **actif** | +3 (parrain), +5 (invité) | Max ~3/event |
| Raccourci payant | € → révélations (vente web) | 3-D Secure |

> Règle d'or : **on récompense la valeur réelle** (photo réellement réclamée),
> jamais l'action seule. Détails : `docs/troc-anti-abus.md`.

## 4. Gamification « héros de la soirée »

- Compteur : *« Tu as fait la soirée de 12 personnes »* (nb de développements de tes uploads).
- Badge **Top contributeur** de l'event + mini-classement.
- Récap partageable *« Ta soirée au Duplex en 9 photos »* (pub gratuite).
- Optionnel : **concours** « meilleure photo », financé par une marque sponsor.

## 5. Écrans à construire

- **Page event** : cover, date, lieu, `N photos · M participants`, bouton *Add my photos* + *Find my photos*.
- **Uploader** : sélecteur multi (hand-pick), barre de progression d'analyse.
- **Mon feed d'event** : mes négatifs (floutés) → développer.
- **Notif** : push « nouvelles photos de toi ».
- **Récap / héros** : compteur + partage.

## 6. Modèle de données (extension du backend existant)

Déjà couvert par `backend/schema.sql` : `events`, `event_members`, `photos`
(`uploader_id`), `photo_faces` (consentement), `reveals`, `wallet_ledger`.

À ajouter :
- `events.join_code` (unique) + page publique de jointure.
- `notifications` (user_id, type, event_id, photo_id, seen_at) pour la notif magique.
- Récompense upload : edge function qui, sur un `reveal`, crédite l'**uploader** de la
  photo (`photos.uploader_id`) via `grant_reveals`, avec plafonds.
- `referrals` (parrain, invité, credited) pour le loop d'invitation.

## 7. Consentement & mineurs (rappel, non négociable)

- Retrouver/développer une photo **où tu es** = pas besoin de l'accord des autres.
- Chacun contrôle **sa** découvrabilité (visage opt-in) et peut **se retirer** (coffre-fort).
- **Aucune** identification d'inconnu à partir du visage (jamais).
- **Pas de reconnaissance des mineurs** ; app **18+** (wedge nightlife) ; visages non-adultes floutés/exclus.
- Diffusion publique d'une photo → consentement des personnes identifiables.

## 8. Client vs backend

| Marche déjà (client) | Nécessite le backend |
|---|---|
| Reconnaissance on-device, sélection hand-pick | Comptes multi-utilisateurs |
| Troc/développer en local, floutage | Events partagés + upload réel (Storage) |
| Invitation (lien WhatsApp/mail) | Crédit du parrain à l'inscription |
| Identification par tap | Notifs push entre appareils, récompense upload |

## 9. KPIs à suivre

- **K-factor** : nouveaux inscrits ramenés par photo (> 1 = machine virale).
- **Photos / event** et **taux de réclamation** (photos développées / photos postées).
- **Rétention 30 j** (la notif magique).
- **Revenu B2B récurrent** + achats conso.

---

**Résumé :** l'organisateur amorce, la reconnaissance crée la magie, la notif fait
revenir, le troc récompense l'upload, l'invitation ramène les absents. Aucun
auto-scan, tout consenti, mineurs exclus.
