# PhotosPartagees — Web app (PWA)

Version web installable sur le téléphone (« Ajouter à l'écran d'accueil ») de
l'app : détection + **reconnaissance faciale dans le navigateur** (face-api.js,
descripteurs 128-d) et upload des photos matchées vers **Supabase Storage**.

> Limite navigateur : pas d'accès automatique à toute la pellicule. Tu ouvres le
> sélecteur de photos iOS et fais **« Tout sélectionner »** ; l'app analyse les
> photos choisies, détecte ton visage et upload les matchs.

## Voir l'app sur ton téléphone (le plus simple : GitHub Pages)

1. Dans le dépôt GitHub : **Settings → Pages → Build and deployment → Source =
   GitHub Actions**.
2. Le workflow `.github/workflows/deploy-web.yml` se déclenche à chaque push qui
   touche `web/` et publie le site.
3. Ouvre l'URL fournie (ex. `https://<user>.github.io/<repo>/`) dans **Safari**
   sur ton iPhone → **Partager → Sur l'écran d'accueil**. Ça apparaît comme une app.

### Tester en local (optionnel)

```bash
cd web
python3 -m http.server 8000
# puis http://localhost:8000 (sur ordinateur)
```

## Utilisation

1. **Choisir mon visage de référence** : une photo de toi bien cadrée.
2. **Choisir mes photos à scanner** : sélectionne-en plusieurs (« Tout sélectionner »).
3. Les photos où ton visage est détecté apparaissent, **regroupées par mois**.
4. **Sélectionne** celles à partager, puis **Partager la sélection**.
5. Récap final + **copie des liens de partage** signés.

## Configuration Supabase (pour l'upload)

Le **scan/matching fonctionne sans Supabase**. Pour activer l'upload, édite
`web/config.js` :

```js
window.SUPABASE_CONFIG = {
  url: "https://<project-ref>.supabase.co",
  anonKey: "<clé anon publique>",
  bucket: "shared-photos",
};
```

- Crée le bucket Storage `shared-photos` dans Supabase.
- Ajoute une policy autorisant l'`insert` (upload). La clé `anon` est publique
  par conception ; protège l'écriture via une policy RLS adaptée à ton besoin.

## Détails techniques

- **face-api.js** (`@vladmandic/face-api`) chargé via CDN ; modèles : SSD
  Mobilenet (détection) + Landmark68 + Recognition (descripteur 128-d).
- **Matching** : distance euclidienne au descripteur de référence, seuil réglable
  (Réglages, défaut 0.55 — plus bas = plus strict).
- **PWA** : `manifest.webmanifest` + `service-worker.js` (cache de l'app shell).
- Les images sont redimensionnées en mémoire avant analyse ; l'upload envoie le
  fichier original.
