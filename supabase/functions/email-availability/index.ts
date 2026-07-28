import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

async function clientKey(request: Request, salt: string): Promise<string> {
  const forwarded = request.headers.get("x-forwarded-for") ?? "";
  const ip = forwarded.split(",")[0]?.trim() ||
    request.headers.get("cf-connecting-ip") ||
    request.headers.get("x-real-ip") ||
    "unknown";
  const bytes = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Service is not configured" }, 503);
  }

  let payload: { email?: unknown };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const email = typeof payload.email === "string"
    ? payload.email.trim().toLowerCase()
    : "";
  const validEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) &&
    email.length <= 254;
  if (!validEmail) {
    return json({ error: "Enter a valid email address" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const key = await clientKey(request, serviceRoleKey.slice(-32));
  const { data: withinQuota, error: quotaError } = await admin.rpc(
    "consume_email_availability_quota",
    { p_client_key: key },
  );
  if (quotaError) {
    console.error("Email availability quota failed", quotaError);
    return json({ error: "Availability check is temporarily unavailable" }, 503);
  }
  if (withinQuota !== true) {
    return json(
      { error: "Too many checks. Please wait a few minutes." },
      429,
    );
  }

  const { data: available, error } = await admin.rpc("is_email_available", {
    p_email: email,
  });
  if (error) {
    console.error("Email availability lookup failed", error);
    return json({ error: "Availability check is temporarily unavailable" }, 503);
  }

  return json({ available: available === true });
});
