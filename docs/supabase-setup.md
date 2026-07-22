# Poze — Allumer le backend (Supabase) en 15 min

Guide express pour passer l'app du **mode local** au **mode backend réel**.
Tout est gratuit (plan free Supabase).

## 1. Créer le projet
1. Va sur **[supabase.com](https://supabase.com)** → **Start your project** → connecte-toi (GitHub).
2. **New project** :
   - **Name** : `poze`
   - **Database password** : génère-en un et garde-le de côté.
   - **Region** : choisis proche de toi (ex. *West EU (Paris)*).
3. Clique **Create new project** et attends ~2 min qu'il se provisionne.

## 2. Créer les tables (le schéma)
1. Menu de gauche → **SQL Editor** → **+ New query**.
2. Ouvre le fichier **`backend/schema.sql`** du repo, **copie tout**, colle dans l'éditeur.
3. Clique **Run** (en bas à droite). Tu dois voir *Success. No rows returned*.

## 3. Créer le bucket de photos
1. Menu de gauche → **Storage** → **New bucket**.
2. **Name** : `event-photos`
3. Laisse **Public** décoché (bucket **privé** — c'est voulu).
4. **Create bucket**.

## 4. Activer la connexion sans friction
1. Menu de gauche → **Authentication** → **Providers** (ou **Sign In / Providers**).
2. Trouve **Anonymous sign-ins** → **active**-le → **Save**.
   *(Pour la prod plus tard : on remplacera par email/OAuth.)*

## 5. Récupérer tes clés
1. Menu de gauche → **Project Settings** (roue crantée) → **API**.
2. Copie **Project URL** (ex. `https://abcdxyz.supabase.co`).
3. Copie **Project API keys → `anon` `public`** (la clé publique — pas la `service_role` !).

## 6. Coller les clés dans l'app
Ouvre **`web/config.js`** et remplis :
```js
window.SUPABASE_CONFIG = {
  url: "https://abcdxyz.supabase.co",   // ← ton Project URL
  anonKey: "eyJhbGciOi...",             // ← ta clé anon public
  bucket: "event-photos",
};
```
Commit + push → GitHub Pages redéploie → **recharge l'app**.

## 7. Vérifier que c'est allumé
- Le bouton **« ＋ Join an event »** apparaît sur l'accueil (il est caché en mode local).
- Dans Supabase → **Table Editor → profiles** : une ligne apparaît quand tu ouvres l'app (ton profil anonyme).
- **Authentication → Users** : un utilisateur anonyme est créé.

## Créer ton premier event (test)
Dans **SQL Editor**, colle (remplace le nom/lieu) :
```sql
insert into public.events (name, place, starts_at, join_code)
values ('Le Duplex', 'Paris · Club', now(), 'DUPLEX24');
```
Puis dans l'app : **＋ Join an event** → tape `DUPLEX24` → l'event apparaît. Tu peux alors **y ajouter des photos** (upload réel).

## ⚠️ Rappels
- La clé **anon** est **publique** par conception (OK côté client). Ne mets **jamais** la clé `service_role`.
- La reconnaissance reste **sur l'appareil** ; on n'envoie au serveur que les visages **consentis**.
- Cadrage **RGPD / mineurs** obligatoire avant tout lancement public.

## Quand tu m'auras donné l'URL + la clé
Je finalise la brique **live** : matching des photos d'event (négatifs) + **développement HD via serveur** (`developPhoto` → URL signée), qu'on pourra enfin tester en vrai.
