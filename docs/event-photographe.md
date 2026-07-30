# Mode event photographe (Option B) — matching sur l'appareil

Le cas « un photographe, 1000 photos, retrouver *tes* photos en soirée » — sans
faire de reconnaissance faciale côté serveur (ta différence face à Memzo/AccioPix).

## Le principe

1. **Le photographe** importe ses photos (« Mode photographe » sur la tuile event).
   L'app, sur *son* appareil, détecte les visages, **uploade les photos** et publie
   **une empreinte anonyme par visage** (`event_face_prints`) — aucune identité, aucun nom.
2. **L'invité** ouvre l'event → onglet **« Mes photos »**. Son app télécharge les
   empreintes et les compare à **son propre visage** (enregistré dans « Moi ») —
   **entièrement sur son téléphone**. Il ne voit que les photos où il apparaît.
3. Il **imprime (gratuit, brandé)** ou **télécharge en HD (payant)**.

Aucun selfie ne quitte l'appareil, aucune reco serveur. Seules des **empreintes
anonymes** et les photos transitent, à l'intérieur de l'event (consenti).

## Côté app (en place)

- `SelfFaceStore` : ton visage de référence, chiffré (défini dans « Moi »).
- `EventFaceMatcher` : encode/décode une empreinte (base64) et matche on-device.
- `EventPhotographerView` : import en masse → upload + `publishEventFace`.
- `EventCloudView` : bascule **Toutes / Mes photos** (`findMyPhotos`) + impression/HD.
- `EventBackendService` : `uploadEventPhoto` (renvoie le path), `publishEventFace`,
  `listEventFacePrints`.

## Côté serveur (à déployer)

- Table `event_face_prints` (voir `backend/schema.sql`) + RLS (membres de l'event).
- Rien d'autre : le matching est chez l'invité.

## Invité sans smartphone (borne physique)

Seul cas où le matching n'est pas sur le tel de l'invité : la **sharing box** fait
le matching sur son propre matériel (avec consentement affiché). Dépend du
fournisseur de borne.

## Limites (honnête)

- Non testé contre un backend live. `uploadEventPhoto` + `publishEventFace` doivent
  être appelés avec un event **synchronisé** (`remoteID` présent) et les politiques
  RLS en place.
- Précision = celle de l'empreinte Vision générique aujourd'hui ; le passage à un
  modèle Core ML (ArcFace) améliorerait nettement le tri « mes photos ».
- Volume : pour 1000 photos, prévoir l'upload en tâche de fond (amélioration future).
