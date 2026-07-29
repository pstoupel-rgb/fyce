# Connexion (Apple / Google / Facebook / email)

Au premier lancement, après l'onboarding, Poze présente un écran de **connexion**.
Options : **Apple**, **Google**, **Facebook**, **compte email**, ou **continuer sans
compte** (mode local — l'app reste utilisable hors ligne).

## Ce qui marche sans backend

- **Continuer sans compte** : mode invité, 100 % local.
- **Sign in with Apple** : fonctionne nativement (crée une session locale). Active
  la capability *Sign in with Apple* sur l'App ID (déjà déclarée dans les
  entitlements).

## Ce qui nécessite Supabase configuré

Google, Facebook et l'email passent par **Supabase Auth (GoTrue)**. Il faut donc
renseigner les clés (voir `backend-events.md`) et activer les providers.

### 1. Providers OAuth

Dashboard Supabase → **Authentication → Providers** :

- **Google** : renseigne le *Client ID* / *Secret* (console Google Cloud).
- **Facebook** : renseigne l'*App ID* / *Secret* (Meta for Developers).

### 2. URL de redirection

Dans **Authentication → URL Configuration → Redirect URLs**, ajoute :

```
poze://auth-callback
```

Le scheme `poze` est déjà déclaré dans l'Info.plist (`CFBundleURLTypes`). Le client
ouvre `…/auth/v1/authorize?provider=…&redirect_to=poze://auth-callback` via
`ASWebAuthenticationSession` et récupère les jetons dans le fragment de l'URL de
retour.

### 3. Email

Rien à faire de plus : `signup` / `token?grant_type=password` sont appelés sur
`…/auth/v1/…`. Pense à régler la confirmation d'email selon ton besoin.

### 4. (Option) Apple ↔ Supabase

Si tu veux une vraie session Supabase pour Apple, active le provider **Apple** dans
le dashboard. Le client tente alors un échange `token?grant_type=id_token` en
best-effort ; sinon il reste en session locale.

## Limites (honnête)

- Ce flux **n'a pas été testé contre un projet live** ni les consoles Google/Meta.
- Les jetons sont stockés en `UserDefaults` — pour la prod, bascule vers le
  **Keychain**.
- « Se déconnecter » se fait dans **Réglages → Compte**.
