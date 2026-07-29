// Supabase Edge Function — webhook Mollie.
//
// Mollie appelle cette URL quand le statut d'un paiement change. On vérifie que
// le paiement est "paid", puis on crédite les reveals de l'utilisateur dans
// `wallet_ledger` (delta = reveals achetés, reason = 'purchase').
//
// Déployer : `supabase functions deploy mollie-webhook`
// Secrets : MOLLIE_API_KEY, SERVICE_ROLE_KEY, SUPABASE_URL
//
// ⚠️ Modèle prêt à brancher — non testé contre un compte Mollie live.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    // Mollie envoie `id=tr_xxx` en form-urlencoded.
    const form = await req.formData();
    const paymentId = form.get("id")?.toString();
    if (!paymentId) return new Response("no id", { status: 400 });

    // On re-vérifie le paiement côté Mollie (ne jamais faire confiance au webhook seul).
    const res = await fetch(`https://api.mollie.com/v2/payments/${paymentId}`, {
      headers: { authorization: `Bearer ${Deno.env.get("MOLLIE_API_KEY")}` },
    });
    const payment = await res.json();
    if (payment.status !== "paid") return new Response("ignored", { status: 200 });

    const reveals = Number(payment.metadata?.reveals ?? 0);
    const userId = payment.metadata?.userId ?? null;
    if (!userId || reveals <= 0) return new Response("no credit target", { status: 200 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
    );

    // Idempotence : ne pas créditer deux fois le même paiement.
    const { data: existing } = await supabase
      .from("wallet_ledger").select("id").eq("ref_id", paymentId).maybeSingle();
    if (existing) return new Response("already credited", { status: 200 });

    await supabase.from("wallet_ledger").insert({
      user_id: userId,
      delta: reveals,
      reason: "purchase",
      ref_id: paymentId,
    });

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
