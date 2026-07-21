# Poze — Anti-abus du troc

Le troc (« contribue pour développer ») ne tient que si on **rend le farming non
rentable**. Principe directeur : **on ne récompense que de la valeur réelle,
créée pour les autres.**

## 1. Récompenser la valeur, pas l'action

| Action | Récompense ? | Pourquoi |
|---|---|---|
| Uploader une photo | ❌ pas à l'upload | Sinon on spamme l'upload |
| Ta photo est **développée par un autre** | ✅ **+1** | Valeur réelle prouvée |
| Partager / inviter (nouvel inscrit actif) | ✅ **+2**, plafonné | Croissance réelle |
| Se développer soi-même | ❌ | Auto-troc |

> Règle d'or : **une révélation ne se gagne que lorsqu'un tiers a tiré de la
> valeur de ta contribution.**

## 2. Bloquer l'auto-troc et les anneaux

- **Pas de self-reward** : tu ne gagnes rien quand tu développes tes propres photos.
- **Détection des cercles fermés** : si A ne développe que B et B que A (ou petits
  groupes en boucle), le gain est **plafonné puis annulé**.
- **Empreinte d'appareil / IP** : plusieurs comptes sur le même appareil/réseau →
  gains mutualisés plafonnés.

## 3. Plafonds & rendement dégressif

- Max **N révélations gagnées / jour** et **/ event**.
- **Rendement décroissant** : les premières contributions rapportent plein tarif,
  puis moins (empêche le grind).
- Récompense de partage : **une seule fois par event**, et créditée seulement si
  l'invité **s'active** (scanne son visage).

## 4. Qualité des contributions

- Une photo uploadée ne « compte » que si elle contient **au moins un visage d'un
  autre participant** et qu'elle est **effectivement développée** par quelqu'un.
- Rejet : captures d'écran, images sans visage, **doublons** (hash perceptuel).
- Un **visage de référence par compte** ; changement de visage limité (anti-usurpation).

## 5. Intégrité technique

- **Toute la logique de gain/dépense est côté serveur** (RPC / edge function) —
  jamais côté client (sinon triche triviale).
- **Ledger append-only** : chaque `+`/`−` est tracé (`wallet_ledger`) et réversible.
- **Rate limiting** + attestation d'appareil ; captcha si comportement suspect.
- **Idempotence** : un développement = une dépense (pas de double-clic exploitable).

## 6. Le raccourci payant (anti-fraude)

- Paiement via prestataire avec **3-D Secure**.
- Révélations créditées **après confirmation** du paiement (webhook), pas avant.
- Suivi des remboursements / litiges → gel des révélations correspondantes.

## 7. Sanctions graduées

1. **Shadow-cap** : les gains suspects n'augmentent plus le solde visible.
2. **Gel** des révélations obtenues frauduleusement.
3. **Bannissement** en cas de fraude avérée (paiement, usurpation de visage).

## 8. Paramètres à calibrer (valeurs de départ)

| Paramètre | Valeur initiale |
|---|---|
| Bienvenue | +1 révélation |
| Développer | −1 |
| Ta photo développée par un tiers | +1 (max 10/jour) |
| Partage → invité actif | +2 (max 3/event) |
| Rendement dégressif | −20 % par palier de 5 gains/jour |

À ajuster avec les données réelles des premiers events (voir le simulateur).
