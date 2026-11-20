import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PRODUCT_ID = "com.kierenpound.undercroft.handover";
const PACKAGE_NAME = "com.kierenpound.undercroft";

const CORS_HEADERS = {
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: CORS_HEADERS,
  });
}

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

interface ServiceAccountCredentials {
  client_email: string;
  private_key: string;
}

function readServiceAccount(): ServiceAccountCredentials {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new HttpError(500, "Google Play verification is not configured");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new HttpError(500, "Google Play service account is not valid JSON");
  }
  const credentials = parsed as Partial<ServiceAccountCredentials>;
  if (
    typeof credentials.client_email !== "string" ||
    typeof credentials.private_key !== "string"
  ) {
    throw new HttpError(500, "Google Play service account is incomplete");
  }
  return {
    client_email: credentials.client_email,
    private_key: credentials.private_key,
  };
}

async function createGoogleAccessToken(): Promise<string> {
  const { client_email, private_key } = readServiceAccount();

  const pem = private_key.replace(/\\n/g, "\n");
  const keyContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(
    atob(keyContents),
    (character) => character.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const issuedAt = Math.floor(Date.now() / 1000);
  const header = base64Url(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const payload = base64Url(JSON.stringify({
    iss: client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: issuedAt,
    exp: issuedAt + 3600,
  }));
  const signingInput = `${header}.${payload}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  const jwt = `${signingInput}.${base64Url(signature)}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = (await tokenResponse.text()).replace(/\s+/g, " ").slice(
      0,
      120,
    );
    console.error(
      `Google OAuth token request failed (status=${tokenResponse.status}, error=${errorText})`,
    );
    throw new HttpError(502, "Could not authenticate with Google Play");
  }

  const tokenBody = await tokenResponse.json() as { access_token?: unknown };
  const accessToken = tokenBody.access_token;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpError(502, "Google did not return an access token");
  }
  return accessToken;
}

interface GoogleProductPurchase {
  purchaseState?: number;
  consumptionState?: number;
  purchaseType?: number;
  orderId?: string;
}

async function fetchGooglePurchase(
  purchaseToken: string,
  accessToken: string,
): Promise<GoogleProductPurchase> {
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(PACKAGE_NAME)
    }/purchases/products/${encodeURIComponent(PRODUCT_ID)}/tokens/${
      encodeURIComponent(purchaseToken)
    }`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );

  if (!response.ok) {
    let errorMessage = "unavailable";
    try {
      const errorBody = await response.json();
      const message = errorBody?.error?.message ?? errorBody?.message;
      if (typeof message === "string") {
        errorMessage = message.replace(/\s+/g, " ").slice(0, 120);
      }
    } catch {
      errorMessage = "non_json_response";
    }
    console.error(
      `Google Play purchase lookup failed (status=${response.status}, error=${errorMessage})`,
    );
    if (response.status === 404 || response.status === 410) {
      throw new HttpError(404, "The Google Play purchase could not be found");
    }
    throw new HttpError(502, "Could not verify the Google Play purchase");
  }

  return (await response.json()) as GoogleProductPurchase;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
      throw new HttpError(401, "Authentication required");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    const adminKey = Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !adminKey) {
      throw new HttpError(
        500,
        "Supabase is not configured for purchase verification",
      );
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      throw new HttpError(400, "Request body must be valid JSON");
    }
    const purchaseToken = (body as Record<string, unknown> | null)
      ?.purchaseToken;
    if (
      typeof purchaseToken !== "string" || purchaseToken.length === 0 ||
      purchaseToken.length > 4096
    ) {
      throw new HttpError(
        400,
        "A valid Google Play purchase token is required",
      );
    }

    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) {
      throw new HttpError(401, "Invalid or expired authentication token");
    }

    const { data: contexts, error: contextError } = await caller.rpc(
      "get_or_create_current_estate_context",
    );
    if (contextError || !Array.isArray(contexts)) {
      throw new HttpError(500, "Could not verify estate ownership");
    }
    const context = contexts[0] as
      | { estate_id?: string; role?: string }
      | undefined;
    if (!context?.estate_id || context.role !== "owner") {
      throw new HttpError(403, "Only an estate owner can unlock invitations");
    }

    const accessToken = await createGoogleAccessToken();
    const purchase = await fetchGooglePurchase(purchaseToken, accessToken);

    // purchaseState: 0 = purchased, 1 = cancelled, 2 = pending.
    // consumptionState: 0 = not consumed, 1 = consumed. For a non-consumable
    // unlock we expect it never to be consumed.
    if (
      purchase.purchaseState !== 0 ||
      purchase.consumptionState === 1
    ) {
      throw new HttpError(
        403,
        "The Google Play purchase is not valid for this unlock",
      );
    }

    // Google orderId is the durable transaction identifier. Use it (when
    // present) so a single purchase cannot unlock more than one estate.
    const transactionId = purchase.orderId ?? purchaseToken;
    if (typeof transactionId !== "string" || transactionId.length === 0) {
      throw new HttpError(
        403,
        "The Google Play purchase is not valid for this unlock",
      );
    }

    // Test purchases (purchaseType === 0) run in Google's test environment.
    const environment = purchase.purchaseType === 0 ? "Test" : "Production";

    const admin = createClient(supabaseUrl, adminKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const estateId = context.estate_id;

    const { data: existingEstate, error: estateLookupError } = await admin
      .from("estate_handover_entitlements")
      .select("estate_id")
      .eq("estate_id", estateId)
      .maybeSingle();
    if (estateLookupError) {
      throw new HttpError(500, "Could not load the estate entitlement");
    }
    if (existingEstate) {
      return jsonResponse({ granted: true, alreadyGranted: true });
    }

    const { data: existingTransaction, error: transactionLookupError } =
      await admin
        .from("estate_handover_entitlements")
        .select("estate_id")
        .eq("store_transaction_id", transactionId)
        .maybeSingle();
    if (transactionLookupError) {
      throw new HttpError(500, "Could not check the transaction record");
    }
    if (existingTransaction) {
      if (existingTransaction.estate_id === estateId) {
        return jsonResponse({ granted: true, alreadyGranted: true });
      }
      throw new HttpError(
        409,
        "This purchase is already linked to another estate",
      );
    }

    const { error: grantError } = await admin
      .from("estate_handover_entitlements")
      .insert({
        estate_id: estateId,
        source: "google_play",
        store_environment: environment,
        store_transaction_id: transactionId,
      });
    if (grantError) {
      const { data: racedEstate } = await admin
        .from("estate_handover_entitlements")
        .select("estate_id")
        .eq("estate_id", estateId)
        .maybeSingle();
      if (racedEstate) {
        return jsonResponse({ granted: true, alreadyGranted: true });
      }

      const { data: racedTransaction } = await admin
        .from("estate_handover_entitlements")
        .select("estate_id")
        .eq("store_transaction_id", transactionId)
        .maybeSingle();
      if (racedTransaction?.estate_id === estateId) {
        return jsonResponse({ granted: true, alreadyGranted: true });
      }
      if (racedTransaction) {
        throw new HttpError(
          409,
          "This purchase is already linked to another estate",
        );
      }

      console.error(
        `Could not grant Google Play entitlement (${grantError.code})`,
      );
      throw new HttpError(500, "Could not save the verified purchase");
    }

    return jsonResponse({ granted: true, environment });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error(
      `Google Play verification failed (${
        error instanceof Error ? error.name : "unknown"
      })`,
    );
    return jsonResponse(
      { error: "Could not verify the Google Play purchase" },
      500,
    );
  }
});
