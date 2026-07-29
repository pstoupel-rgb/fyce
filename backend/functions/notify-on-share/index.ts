// Supabase Edge Function — « notif magique ».
//
// Déclenchée quand une personne est identifiée sur une photo partagée
// (insert dans `photo_faces` avec consentement). Elle :
//   1. crée une ligne `notifications` pour l'utilisateur taggé,
//   2. envoie un push APNs à ses appareils (`device_tokens`).
//
// À déployer : `supabase functions deploy notify-on-share`
// Puis la brancher via un Database Webhook sur INSERT de `public.photo_faces`
// (Dashboard → Database → Webhooks), ou l'appeler depuis un trigger `pg_net`.
//
// Secrets requis (supabase secrets set …) :
//   SERVICE_ROLE_KEY, SUPABASE_URL,
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY (p8, base64),
//   APNS_ENV = "sandbox" | "production"
//
// ⚠️ Ce fichier est un modèle prêt à brancher — non testé contre un projet live.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: { photo_id: string; user_id: string | null; consented: boolean };
}

Deno.serve(async (req: Request) => {
  try {
    const payload = (await req.json()) as WebhookPayload;
    const face = payload.record;
    if (!face?.user_id || !face.consented) {
      return new Response("skip (no user or no consent)", { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
    );

    // Contexte : de quel event vient la photo ?
    const { data: photo } = await supabase
      .from("photos")
      .select("event_id, events(name)")
      .eq("id", face.photo_id)
      .single();

    const eventName = (photo as any)?.events?.name ?? "un event";
    const body = `📸 De nouvelles photos de toi (${eventName})`;

    // 1) notification en base
    await supabase.from("notifications").insert({
      user_id: face.user_id,
      kind: "new_photos",
      event_id: (photo as any)?.event_id ?? null,
      photo_id: face.photo_id,
      body,
    });

    // 2) push APNs vers les appareils de l'utilisateur
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", face.user_id);

    for (const t of tokens ?? []) {
      await sendAPNs((t as any).token, body).catch((e) =>
        console.error("APNs error", e)
      );
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});

// --- APNs via JWT (HTTP/2). Implémentation minimale ; voir docs/ios-push-setup.md. ---
async function sendAPNs(deviceToken: string, body: string): Promise<void> {
  const jwt = await apnsJWT();
  const host = Deno.env.get("APNS_ENV") === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  const res = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
      "apns-push-type": "alert",
    },
    body: JSON.stringify({
      aps: { alert: { title: "Poze", body }, sound: "default", badge: 1 },
    }),
  });
  if (res.status >= 300) throw new Error(`APNs ${res.status}: ${await res.text()}`);
}

// Signe le JWT ES256 attendu par APNs à partir de la clé .p8.
async function apnsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const p8 = atob(Deno.env.get("APNS_PRIVATE_KEY")!); // .p8 en base64
  const header = { alg: "ES256", kid: keyId };
  const now = Math.floor(Date.now() / 1000);
  const claims = { iss: teamId, iat: now };

  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claims)}`;

  const pem = p8.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(unsigned),
    ),
  );
  const b64 = btoa(String.fromCharCode(...sig))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${unsigned}.${b64}`;
}
