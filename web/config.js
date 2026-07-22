// Configuration Supabase (clé anon = publique, OK côté client).
// Le scan + le matching fonctionnent SANS Supabase ; seul l'upload en a besoin.
//
// Crée un bucket Storage (ex. "shared-photos") dans ton projet Supabase, puis
// renseigne ci-dessous. Pense à autoriser l'upload via une policy RLS sur le bucket.
window.SUPABASE_CONFIG = {
  url: "",          // ex. "https://abcdxyz.supabase.co"
  anonKey: "",      // ta clé anon (publique)
  bucket: "event-photos",
};
