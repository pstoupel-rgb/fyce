-- Poze — Schéma Supabase (Postgres)
-- Fondation backend : comptes, events, photos, troc (révélations).
-- La logique de gain/dépense vit CÔTÉ SERVEUR (fonctions SECURITY DEFINER) pour
-- empêcher toute triche côté client. Voir backend/README.md.

-- ─────────────────────────────────────────────────────────────
-- Profils
-- ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

-- Empreinte de visage : OPTIONNELLE et sensible (donnée biométrique).
-- Recommandé : garder la reconnaissance sur l'appareil. Si stockée, RLS stricte,
-- consentement explicite, chiffrement. (pgvector requis : create extension vector)
create table if not exists public.face_prints (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  embedding  jsonb,               -- ou vector(128) si extension pgvector
  updated_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────────────────────
create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  place        text,
  starts_at    timestamptz,
  join_code    text unique,        -- code du QR / lien d'accès à l'event
  cover_path   text,
  organizer_id uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);

create table if not exists public.event_members (
  event_id uuid references public.events(id) on delete cascade,
  user_id  uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- ─────────────────────────────────────────────────────────────
-- Photos & visages détectés
-- ─────────────────────────────────────────────────────────────
create table if not exists public.photos (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  uploader_id  uuid references public.profiles(id) on delete set null,
  storage_path text not null,     -- objet dans le bucket Storage
  created_at   timestamptz not null default now()
);

-- Un visage reconnu dans une photo, rattaché (avec consentement) à un utilisateur.
create table if not exists public.photo_faces (
  id         uuid primary key default gen_random_uuid(),
  photo_id   uuid not null references public.photos(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete set null,
  consented  boolean not null default false,
  created_at timestamptz not null default now(),
  unique (photo_id, user_id)
);

-- Développements (une révélation dépensée pour obtenir le HD).
create table if not exists public.reveals (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  photo_id   uuid not null references public.photos(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, photo_id)      -- idempotence : on ne développe qu'une fois
);

-- ─────────────────────────────────────────────────────────────
-- Le troc : ledger append-only. Solde = somme des deltas.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.wallet_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  delta      integer not null,             -- +gain / -dépense
  reason     text not null,                -- 'welcome' | 'reveal' | 'reciprocity' | 'share' | 'purchase'
  ref_id     uuid,
  created_at timestamptz not null default now()
);
create index if not exists wallet_ledger_user_idx on public.wallet_ledger(user_id);

create or replace view public.wallet_balance as
  select user_id, coalesce(sum(delta), 0)::int as balance
  from public.wallet_ledger group by user_id;

-- Achats (raccourci payant) crédités après confirmation du paiement.
create table if not exists public.purchases (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  pack         text not null,
  amount_cents integer not null,
  provider_ref text,
  credited     integer not null default 0,
  created_at   timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────
alter table public.profiles       enable row level security;
alter table public.face_prints    enable row level security;
alter table public.events         enable row level security;
alter table public.event_members  enable row level security;
alter table public.photos         enable row level security;
alter table public.photo_faces    enable row level security;
alter table public.reveals        enable row level security;
alter table public.wallet_ledger  enable row level security;
alter table public.purchases      enable row level security;

-- Profil : chacun lit/écrit le sien.
create policy "own profile"        on public.profiles    for all using (id = auth.uid()) with check (id = auth.uid());
create policy "own faceprint"      on public.face_prints for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Events : visibles par leurs membres ; créés par l'organisateur.
create policy "member reads event" on public.events for select
  using (exists (select 1 from public.event_members m where m.event_id = id and m.user_id = auth.uid()));
create policy "own membership"     on public.event_members for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Photos : visibles par les membres de l'event (en aperçu). Le HD passe par la RPC.
create policy "member reads photos" on public.photos for select
  using (exists (select 1 from public.event_members m where m.event_id = photos.event_id and m.user_id = auth.uid()));

-- Visages : chacun voit/consent ceux qui le concernent.
create policy "own faces" on public.photo_faces for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Ledger, reveals, purchases : lecture seule de ses propres lignes.
-- (Les écritures se font UNIQUEMENT via les fonctions SECURITY DEFINER ci-dessous.)
create policy "read own ledger"    on public.wallet_ledger for select using (user_id = auth.uid());
create policy "read own reveals"   on public.reveals       for select using (user_id = auth.uid());
create policy "read own purchases" on public.purchases     for select using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────
-- Logique de troc — côté serveur, atomique
-- ─────────────────────────────────────────────────────────────

-- Développer une photo : vérifie le solde, débite 1, récompense les personnes
-- présentes sur la photo (réciprocité), renvoie le chemin Storage du HD.
create or replace function public.develop_photo(p_photo_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_bal   int;
  v_path  text;
  v_event uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select storage_path, event_id into v_path, v_event
  from public.photos where id = p_photo_id;
  if v_path is null then raise exception 'photo not found'; end if;

  -- doit être membre de l'event
  if not exists (select 1 from public.event_members
                 where event_id = v_event and user_id = v_uid) then
    raise exception 'not a member of this event';
  end if;

  -- déjà développée ? on renvoie sans re-débiter (idempotence)
  if exists (select 1 from public.reveals where user_id = v_uid and photo_id = p_photo_id) then
    return v_path;
  end if;

  select balance into v_bal from public.wallet_balance where user_id = v_uid;
  if coalesce(v_bal, 0) < 1 then raise exception 'not enough reveals'; end if;

  insert into public.reveals(user_id, photo_id) values (v_uid, p_photo_id);
  insert into public.wallet_ledger(user_id, delta, reason, ref_id)
    values (v_uid, -1, 'reveal', p_photo_id);

  -- réciprocité : +1 aux personnes (consenties) présentes sur la photo, sauf soi.
  -- (Les plafonds anti-abus sont à appliquer ici — voir docs/troc-anti-abus.md.)
  insert into public.wallet_ledger(user_id, delta, reason, ref_id)
    select pf.user_id, 1, 'reciprocity', p_photo_id
    from public.photo_faces pf
    where pf.photo_id = p_photo_id and pf.user_id is not null
      and pf.user_id <> v_uid and pf.consented;

  -- récompense l'UPLOADER quand un tiers développe sa photo (le moteur du supply).
  insert into public.wallet_ledger(user_id, delta, reason, ref_id)
    select p.uploader_id, 1, 'upload_reward', p_photo_id
    from public.photos p
    where p.id = p_photo_id and p.uploader_id is not null and p.uploader_id <> v_uid;

  return v_path;
end;
$$;

-- Créditer une contribution (partage, etc.) — à appeler depuis une edge function
-- qui applique les plafonds et vérifie la réalité de la contribution.
create or replace function public.grant_reveals(p_user uuid, p_amount int, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_amount <= 0 then return; end if;
  insert into public.wallet_ledger(user_id, delta, reason) values (p_user, p_amount, p_reason);
end;
$$;

-- Bienvenue : +1 à la création du profil.
create or replace function public.handle_new_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.wallet_ledger(user_id, delta, reason) values (new.id, 1, 'welcome');
  return new;
end;
$$;

drop trigger if exists on_profile_created on public.profiles;
create trigger on_profile_created after insert on public.profiles
  for each row execute function public.handle_new_profile();

-- ─────────────────────────────────────────────────────────────
-- Loop d'event : jointure par code, notifications, parrainage
-- ─────────────────────────────────────────────────────────────

-- Rejoindre un event via son code (QR / lien). Ajoute le membre + notif.
create or replace function public.join_event(p_code text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_event uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select id into v_event from public.events where join_code = p_code;
  if v_event is null then raise exception 'event not found'; end if;
  insert into public.event_members(event_id, user_id) values (v_event, v_uid)
    on conflict do nothing;
  return v_event;
end;
$$;

-- Notifications (la « notif magique »).
create table if not exists public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null,                 -- 'new_photos' | 'tagged' | 'invite_joined' …
  event_id   uuid references public.events(id) on delete cascade,
  photo_id   uuid references public.photos(id) on delete cascade,
  body       text,
  seen_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, seen_at);
alter table public.notifications enable row level security;
create policy "read own notifications" on public.notifications for select using (user_id = auth.uid());
create policy "update own notifications" on public.notifications for update using (user_id = auth.uid());

-- Parrainage (le loop d'invitation).
create table if not exists public.referrals (
  id          bigint generated always as identity primary key,
  inviter_id  uuid references public.profiles(id) on delete set null,
  invited_id  uuid references public.profiles(id) on delete cascade,
  code        text,
  credited    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (invited_id)
);
alter table public.referrals enable row level security;
create policy "read own referrals" on public.referrals for select
  using (inviter_id = auth.uid() or invited_id = auth.uid());

-- Crédite le parrain (+3) et l'invité (+5) — à appeler quand l'invité devient actif.
create or replace function public.credit_referral(p_inviter uuid, p_invited uuid, p_code text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_inviter is null or p_invited is null or p_inviter = p_invited then return; end if;
  insert into public.referrals(inviter_id, invited_id, code, credited)
    values (p_inviter, p_invited, p_code, true)
    on conflict (invited_id) do nothing;
  if found then
    insert into public.wallet_ledger(user_id, delta, reason) values (p_inviter, 3, 'referral');
    insert into public.wallet_ledger(user_id, delta, reason) values (p_invited, 5, 'referral_bonus');
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- Tokens d'appareil (push iOS/Android) — la « notif magique »
-- ─────────────────────────────────────────────────────────────
create table if not exists public.device_tokens (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null,
  platform   text not null default 'ios',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table public.device_tokens enable row level security;
create policy "own device tokens" on public.device_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────
-- Mode event photographe (Option B) : empreintes de visage ANONYMES.
-- Le photographe publie une empreinte par visage détecté (aucune identité).
-- L'invité télécharge ces empreintes et matche contre son propre visage,
-- ENTIÈREMENT sur son téléphone. Aucune reconnaissance faciale côté serveur.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.event_face_prints (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  storage_path text not null,          -- la photo (bucket Storage)
  print_b64    text not null,          -- VNFeaturePrintObservation archivé, base64
  created_at   timestamptz not null default now()
);
create index if not exists event_face_prints_event_idx on public.event_face_prints(event_id);
alter table public.event_face_prints enable row level security;

-- Les membres de l'event peuvent lire les empreintes (pour matcher en local)…
create policy "members read event face prints"
  on public.event_face_prints for select to authenticated
  using (event_id in (select event_id from public.event_members where user_id = auth.uid()));

-- …et en insérer (le photographe est un membre de l'event).
create policy "members add event face prints"
  on public.event_face_prints for insert to authenticated
  with check (event_id in (select event_id from public.event_members where user_id = auth.uid()));
