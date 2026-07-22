// Poze — Client backend Supabase.
// Implémente le vrai multi-utilisateur (auth, events, upload, développer, portefeuille,
// notifs) contre backend/schema.sql. Activé dès que window.SUPABASE_CONFIG est rempli.
//
// ⚠️ Non testé en live ici : nécessite un projet Supabase (URL + clé anon) + le schéma
// appliqué + un bucket Storage privé (défaut : "event-photos"). Voir backend/README.md.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cfg = window.SUPABASE_CONFIG || {};
const BUCKET = cfg.bucket || 'event-photos';
const configured = !!(cfg.url && cfg.anonKey && !String(cfg.url).includes('YOUR-') && !String(cfg.anonKey).includes('YOUR-'));
const sb = configured ? createClient(cfg.url, cfg.anonKey) : null;

async function uid() {
  const { data } = await sb.auth.getUser();
  return data && data.user ? data.user.id : null;
}

export const Backend = {
  available: configured,

  // --- Auth (anonyme : zéro friction ; à remplacer par email/OAuth pour la prod) ---
  async signIn() {
    if (!(await uid())) await sb.auth.signInAnonymously();
    return uid();
  },
  async ensureProfile(displayName) {
    const id = await uid();
    if (!id) throw new Error('not authenticated');
    await sb.from('profiles').upsert({ id, display_name: displayName || null }, { onConflict: 'id' });
    return id;
  },

  // --- Portefeuille (troc) ---
  async walletBalance() {
    const id = await uid();
    const { data } = await sb.from('wallet_balance').select('balance').eq('user_id', id).maybeSingle();
    return (data && data.balance) || 0;
  },

  // --- Events ---
  async listEvents() {
    const { data, error } = await sb.from('events').select('*').order('starts_at', { ascending: false });
    if (error) throw error;
    return data || [];
  },
  async joinEvent(code) {
    const { data, error } = await sb.rpc('join_event', { p_code: code });
    if (error) throw error;
    return data; // event id
  },
  async createEvent({ name, place, startsAt, joinCode }) {
    const id = await uid();
    const { data, error } = await sb.from('events')
      .insert({ name, place, starts_at: startsAt, join_code: joinCode, organizer_id: id })
      .select().single();
    if (error) throw error;
    await sb.from('event_members').insert({ event_id: data.id, user_id: id });
    return data;
  },

  // --- Photos ---
  async uploadPhotos(eventId, files, onProgress) {
    const id = await uid();
    const out = [];
    for (let i = 0; i < files.length; i++) {
      const f = files[i];
      const safe = f.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `${eventId}/${id}/${i}-${safe}`;
      const up = await sb.storage.from(BUCKET).upload(path, f, { contentType: f.type || 'image/jpeg', upsert: true });
      if (up.error) continue;
      const ins = await sb.from('photos').insert({ event_id: eventId, uploader_id: id, storage_path: path }).select().single();
      if (!ins.error) out.push(ins.data);
      if (onProgress) onProgress(i + 1, files.length);
    }
    return out;
  },
  async eventPhotos(eventId) {
    const { data, error } = await sb.from('photos').select('*').eq('event_id', eventId).order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  },

  // Enregistre un visage reconnu (avec consentement) — matching fait sur l'appareil.
  async tagFace(photoId, userId, consented = true) {
    await sb.from('photo_faces').upsert({ photo_id: photoId, user_id: userId, consented }, { onConflict: 'photo_id,user_id' });
  },

  // --- Développer (dépense 1 révélation côté serveur, renvoie une URL signée HD) ---
  async developPhoto(photoId) {
    const { data: path, error } = await sb.rpc('develop_photo', { p_photo_id: photoId });
    if (error) throw error;                       // ex. 'not enough reveals'
    return this.signedUrl(path);
  },
  async signedUrl(path, expiresIn = 3600) {
    const { data, error } = await sb.storage.from(BUCKET).createSignedUrl(path, expiresIn);
    if (error) throw error;
    return data.signedUrl;
  },

  // --- Notifications (la « notif magique ») ---
  async notifications() {
    const id = await uid();
    const { data } = await sb.from('notifications').select('*').eq('user_id', id).order('created_at', { ascending: false }).limit(30);
    return data || [];
  },
  async markSeen(notifId) {
    await sb.from('notifications').update({ seen_at: new Date().toISOString() }).eq('id', notifId);
  },
};

export default Backend;
