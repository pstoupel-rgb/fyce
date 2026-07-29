# Impression event & « sharing box »

Aux events, un photographe prend des photos. Deux façons pour les invités de les
récupérer :

- **Imprimer — gratuit.** L'app compose une image **brandée à l'event** (logo ou
  nom + petite marque Poze) et l'envoie à l'impression. Gratuit (offert par
  l'organisateur / le photographe) → viralité physique : chaque tirage porte le logo.
- **Télécharger en HD — payant.** Coûte des **reveals** (2 par photo par défaut),
  car c'est le fichier original que l'invité garde.

## Ce qui est en place (natif)

- `PozeEvent.logoData` : logo optionnel de l'event (réglé dans l'éditeur d'event).
- `PrintComposer.brandedImage(photo:event:)` : rend la carte imprimable (photo +
  bandeau logo/nom + marque Poze).
- `PrintComposer.print(_:jobName:)` : ouvre la feuille **AirPrint** — marche avec
  toute imprimante AirPrint, y compris une sharing box AirPrint, sans backend.
- `EventCloudView` : sélection des photos → « Imprimer (gratuit) » / « Télécharger
  HD · N reveals ».

## Sharing box non-AirPrint (option backend)

Si la borne n'est pas AirPrint mais expose une API ou une file d'attente :

1. Table `print_jobs(event_id, storage_path, status, created_at)`.
2. L'app insère un job (photo brandée uploadée) au lieu d'AirPrint.
3. La borne **poll** les jobs `pending` de son event et imprime, puis passe à `done`.

C'est une petite Edge Function + un endpoint de polling à ajouter — non fait ici,
mais l'architecture est prête (branding + sélection + upload existent déjà).

## Limites (honnête)

- AirPrint est natif et fonctionne. L'intégration d'une **sharing box propriétaire**
  dépend de son SDK/API (à voir avec le fournisseur).
- Le débit (gratuit/payant) est réglable : `downloadCostPerPhoto` dans `EventCloudView`.
