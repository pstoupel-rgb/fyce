# La « notif magique » — « X a de nouvelles photos de toi »

Le moteur viral : **ce n'est pas toi qui cherches tes photos, c'est celui qui les a
qui te trouve** — et la reconnaissance reste sur *son* appareil (privacy intacte).

## Le flux

1. Thomas ouvre Poze. Son téléphone reconnaît **Léa** sur ses photos (on-device).
2. Il garde/partage ces photos → l'app les envoie à l'event et **rattache le visage
   de Léa** (`photo_faces`, avec le consentement requis).
3. La fonction `notify-on-share` crée une notification pour Léa **et** lui envoie un
   **push APNs**.
4. Léa reçoit « 📸 De nouvelles photos de toi » → ouvre l'app → onglet **Activité** →
   récupère (et développe) **les photos qu'elle choisit**.

## Côté app (déjà en place)

- `ActivityFeedView` : le fil de réception (« nouvelles photos de toi »), avec
  activation des notifications et une **démo locale** testable sans backend
  (`PushNotificationManager.scheduleMagicNotificationDemo`).
- `EventBackendService.listNotifications()` : lecture des notifications (pull).
- Enregistrement du token APNs : `PushNotificationManager` + `PushRegistrationService`
  → table `device_tokens`.

## Côté serveur (à brancher)

1. **Déployer** la fonction :
   ```bash
   supabase functions deploy notify-on-share
   ```
2. **Webhook** : Dashboard → Database → Webhooks → sur `INSERT` de
   `public.photo_faces` → POST vers la fonction.
3. **Secrets** (compte développeur Apple requis pour APNs) :
   ```bash
   supabase secrets set APNS_KEY_ID=… APNS_TEAM_ID=… APNS_BUNDLE_ID=com.photospartagees.app \
     APNS_ENV=sandbox APNS_PRIVATE_KEY="$(base64 -w0 AuthKey_XXXX.p8)" \
     SERVICE_ROLE_KEY=… SUPABASE_URL=…
   ```

## Rattacher un visage à un utilisateur

Pour notifier la bonne personne, il faut lier le visage reconnu (local) à un
utilisateur serveur. Deux voies, non exclusives :

- **Ami déjà inscrit** : quand un ami rejoint via ton lien/QR, on garde la
  correspondance `friendID ↔ user_id` ; au partage, on insère `photo_faces(user_id)`.
- **Invitation** : si la personne n'est pas encore sur Poze, on lui envoie un lien
  (WhatsApp/email). À l'inscription, elle récupère les photos en attente et vous
  gagnez tous les deux des « poze ».

## Limites (honnête)

La fonction est un **modèle prêt à brancher**, non testé contre un projet live.
L'envoi réel de push nécessite : projet Supabase + **compte développeur Apple**
(clé APNs `.p8`) + les politiques RLS de `photo_faces` / `device_tokens`.
