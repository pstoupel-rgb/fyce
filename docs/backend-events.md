# Events partagés via Supabase (optionnel)

Par défaut, Poze fonctionne **100 % en local** : les groupes, events et l'historique
vivent sur l'appareil, et le QR d'un event recrée l'event chez celui qui le scanne.

Le backend Supabase sert à **synchroniser les events entre téléphones** (adhésion
par QR, puis — étape suivante — partage des photos). Il est entièrement optionnel :
tant que les clés ne sont pas renseignées, `EventBackendService.isEnabled` est faux
et rien n'est appelé.

## 1. Déployer le schéma

Dans le SQL editor de ton projet Supabase, exécute `backend/schema.sql`. Il crée
notamment les tables `events`, `event_members` et la fonction `join_event(p_code)`.

## 2. Activer l'auth anonyme

`join_event` exige un utilisateur (`auth.uid()`). Le client se connecte donc en
**anonyme**. Dans le dashboard : **Authentication → Providers → Anonymous sign-ins →
Enabled**.

## 3. Politiques RLS

Autorise l'`insert` sur `events` et l'appel de `join_event` pour le rôle
authentifié (anonyme inclus). Exemple minimal :

```sql
alter table public.events enable row level security;

create policy "authed can create events"
  on public.events for insert
  to authenticated
  with check (true);

create policy "members can read their events"
  on public.events for select
  to authenticated
  using (
    id in (select event_id from public.event_members where user_id = auth.uid())
  );
```

## 4. Renseigner les clés

Copie `Config/Secrets.example.xcconfig` vers `Config/Secrets.xcconfig` (non commité)
et remplis :

```
SUPABASE_HOST = ton-ref.supabase.co
SUPABASE_ANON_KEY = ta_clé_anon
SUPABASE_BUCKET = shared-photos
```

Au prochain build, la création d'un event et le scan d'un QR appelleront le backend
**en best-effort** (create event / `join_event`), sans jamais bloquer le flux local.

## Limites (honnête)

- Ce client REST **n'a pas été testé contre un projet live** — il est écrit pour
  s'activer proprement une fois les clés en place, mais prévois une passe de test.
- Le **partage des photos** d'un event entre membres n'est pas encore branché :
  l'upload/stockage existe déjà (`SupabaseService`), mais le lien photos↔event
  (tables `photos` / `photo_faces`) reste à câbler. C'est la prochaine étape logique.
- Ne mets **jamais** la clé `service_role` dans l'app. Clé `anon` + RLS uniquement.
