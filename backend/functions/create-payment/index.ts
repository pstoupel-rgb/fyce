// Supabase Edge Function — création d'un paiement Mollie (checkout web).
//
// Permet de vendre des packs de reveals hors App Store : Bancontact, carte,
// Apple Pay, iDEAL… avec de meilleures marges que l'achat intégré Apple.
//
// Déployer : `supabase functions deploy create-payment`
// Secrets : `supabase secrets set MOLLIE_API_KEY=live_xxx PUBLIC_SITE_URL=https://poze.app`
//
// ⚠️ Modèle prêt à brancher — non testé contre un compte Mollie live.

const PACKS: Record<string, { reveals: number; amount: string; desc: string }> = {
  reveals10: { reveals: 10, amount: "2.99", desc: "10 reveals Poze" },
  reveals30: { reveals: 30, amount: "6.99", desc: "30 reveals Poze" },
  reveals100: { reveals: 100, amount: "19.99", desc: "100 reveals Poze" },
};

Deno.serve(async (req: Request) => {
  try {
    const { pack, userId } = await req.json();
    const p = PACKS[pack];
    if (!p) return json({ error: "unknown pack" }, 400);

    const site = Deno.env.get("PUBLIC_SITE_URL") ?? "https://poze.app";
    const payment = await fetch("https://api.mollie.com/v2/payments", {
      method: "POST",
      headers: {
        "authorization": `Bearer ${Deno.env.get("MOLLIE_API_KEY")}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        amount: { currency: "EUR", value: p.amount },
        description: p.desc,
        redirectUrl: `${site}/merci`,
        webhookUrl: `${site}/functions/v1/mollie-webhook`,
        // On garde le contexte pour créditer le bon compte au webhook.
        metadata: { pack, reveals: p.reveals, userId: userId ?? null },
        // method: ["bancontact","creditcard","applepay","ideal"], // optionnel
      }),
    });

    const data = await payment.json();
    const checkoutUrl = data?._links?.checkout?.href;
    if (!checkoutUrl) return json({ error: "mollie error", detail: data }, 502);
    return json({ checkoutUrl });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// NB : une seconde fonction `mollie-webhook` doit, à réception du paiement "paid",
// créditer `wallet_ledger` (delta = reveals, reason = 'purchase') pour metadata.userId.
