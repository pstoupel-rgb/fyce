# Poze — assets de marque

Le symbole est un **diaphragme d'objectif** (le « o » de *poze*). Sobre, monochrome,
recolorable.

| Fichier | Usage |
|---------|-------|
| `poze-mark.svg` | Le symbole seul, en `currentColor` (hérite de la couleur du texte). À poser sur n'importe quel fond. |
| `poze-appicon.svg` | **Icône d'app retenue** — plein cadre, encre + halo violet + marque blanc cassé. Exportée en `Icon-1024.png` dans le catalogue d'assets (`PhotosPartagees/Resources/Assets.xcassets/AppIcon.appiconset`). |
| `poze-icon-dark.svg` | Variante tuile sombre (coins arrondis) + marque blanc cassé. |
| `poze-icon-light.svg` | Variante claire — tuile ivoire + marque encre. |

**Direction retenue : #3 « expressif · halo violet »** — sobre + une signature de
couleur. L'icône est déjà câblée dans Xcode
(`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` dans `project.yml`). Le PNG 1024 est
opaque (sans canal alpha) → conforme App Store.

- Couleurs de marque : encre `#0d0d12`, blanc cassé `#f4f3ef`, accent champagne `#d8c3a0`.
- Pour l'App Store (1024×1024), exporter `poze-icon-dark.svg` en PNG sans transparence.
- Le mot-symbole « poze » utilise le symbole comme lettre « o » ; pour un logo
  définitif, vectoriser la typo (indépendance de police).
