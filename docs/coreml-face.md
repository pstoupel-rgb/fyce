# Reconnaissance faciale Core ML (précision)

L'app produit une `FaceSignature` (vecteur `[Float]`) par visage. Deux backends,
choisis **automatiquement** :

- **Core ML** — si un modèle de reconnaissance faciale est présent dans le bundle
  (précision proche de l'état de l'art, ~99 % en bonnes conditions).
- **Vision** (repli) — empreinte d'image générique d'Apple. L'app marche sans
  modèle, avec une précision moindre. C'est le comportement actuel.

Tout le reste de l'app (matching, persistance, mode event) est **indépendant du
backend** : ajouter le modèle améliore la précision sans autre changement.

## Ajouter un modèle

1. Récupère un modèle d'**embedding facial** exporté en Core ML — image de visage
   en entrée → vecteur d'embedding en sortie. Options courantes :
   - **FaceNet** (512-d) ou **ArcFace / MobileFaceNet** convertis via
     `coremltools` depuis PyTorch/ONNX.
   - Cherche « FaceNet coreml » / « MobileFaceNet mlmodel » (modèles ouverts).
2. Nomme-le **`FaceEmbedding.mlpackage`** (ou `FaceNet` / `ArcFace`) et glisse-le
   dans le target `PhotosPartagees` (coché « Copy Bundle Resources »).
   XcodeGen l'embarquera automatiquement (le dossier est déjà globé).
3. Rebuild. Au lancement, `FaceEmbedder` détecte le modèle et l'utilise
   (`backendName == "Core ML"`).

## Calibration

Le seuil (`FaceMatcher.threshold`, défaut `0.6`) est calé pour les vecteurs
**Vision** (distance L2 ≈ l'ancienne `computeDistance`). Un modèle Core ML sort
des vecteurs normalisés : **recalibre le seuil** (souvent ~0.9–1.2 en L2, ou
bascule sur une distance cosinus). Règle-le dans les Réglages (« Sensibilité »)
ou dans `FaceMatcher`.

## Détails techniques

- Prétraitement : `CoreMLFaceEmbedder` passe le visage recadré via
  `VNCoreMLRequest` (`.centerCrop`). Selon le modèle, une **normalisation**
  spécifique peut être nécessaire (ex. ArcFace : `(x-127.5)/128`) — à intégrer
  au modèle (couche de préproc) ou dans `vector(for:)`.
- Les signatures sont **Codable** : persistées chiffrées (amis) et transmissibles
  en base64 (mode event, empreintes anonymes).

## Limite (honnête)

Ce câblage est écrit mais **non testé avec un vrai modèle** ici. La bascule
Vision→Core ML est prévue pour être transparente ; prévois une passe de test +
recalibration du seuil quand tu ajoutes le `.mlpackage`.
