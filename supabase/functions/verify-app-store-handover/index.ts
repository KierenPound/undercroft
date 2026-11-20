import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PRODUCT_ID = "com.kierenpound.undercroft.handover";
const BUNDLE_ID = "com.kierenpound.undercroft";
const APPLE_HOSTS = [
  {
    baseUrl: "https://api.storekit.itunes.apple.com",
    environment: "Production",
  },
  {
    baseUrl: "https://api.storekit-sandbox.itunes.apple.com",
    environment: "Sandbox",
  },
] as const;

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

function decodeBase64Url(value: string): Uint8Array {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

async function createAppStoreApiToken(): Promise<string> {
  const issuerId = Deno.env.get("APP_STORE_CONNECT_ISSUER_ID");
  const keyId = Deno.env.get("APP_STORE_CONNECT_KEY_ID");
  const privateKey = Deno.env.get("APP_STORE_CONNECT_PRIVATE_KEY");
  if (!issuerId || !keyId || !privateKey) {
    throw new HttpError(500, "App Store verification is not configured");
  }

  const pem = privateKey.replace(/\\n/g, "\n");
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
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const issuedAt = Math.floor(Date.now() / 1000);
  const header = base64Url(
    JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }),
  );
  const payload = base64Url(JSON.stringify({
    iss: issuerId,
    iat: issuedAt,
    exp: issuedAt + 300,
    aud: "appstoreconnect-v1",
    bid: BUNDLE_ID,
  }));
  const signingInput = `${header}.${payload}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64Url(signature)}`;
}

function readSignedTransactionPayload(
  signedInfo: string,
): Record<string, unknown> {
  const parts = signedInfo.split(".");
  if (parts.length !== 3) {
    throw new HttpError(502, "Apple returned invalid transaction information");
  }
  try {
    const payload = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(parts[1])),
    );
    if (
      payload === null || typeof payload !== "object" || Array.isArray(payload)
    ) {
      throw new Error("Invalid payload");
    }
    return payload as Record<string, unknown>;
  } catch {
    throw new HttpError(502, "Apple returned invalid transaction information");
  }
}

async function fetchAppleTransaction(
  transactionId: string,
  apiToken: string,
): Promise<{ transaction: Record<string, unknown>; environment: string }> {
  for (const apple of APPLE_HOSTS) {
    const response = await fetch(
      `${apple.baseUrl}/inApps/v1/transactions/${
        encodeURIComponent(transactionId)
      }`,
      { headers: { Authorization: `Bearer ${apiToken}` } },
    );
    if (response.status === 404) continue;
    if (!response.ok) {
      console.error(`Apple transaction lookup failed (${response.status})`);
      throw new HttpError(502, "Could not verify the App Store purchase");
    }

    const body = await response.json();
    const signedInfo = body?.signedTransactionInfo;
    if (typeof signedInfo !== "string") {
      throw new HttpError(
        502,
        "Apple returned incomplete transaction information",
      );
    }
    return {
      transaction: readSignedTransactionPayload(signedInfo),
      environment: apple.environment,
    };
  }

  throw new HttpError(404, "The App Store transaction could not be found");
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
    const transactionId = (body as Record<string, unknown> | null)
      ?.transactionId;
    if (
      typeof transactionId !== "string" || !/^[0-9]{1,32}$/.test(transactionId)
    ) {
      throw new HttpError(400, "A valid App Store transaction ID is required");
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

    const apiToken = await createAppStoreApiToken();
    const { transaction, environment } = await fetchAppleTransaction(
      transactionId,
      apiToken,
    );
    if (
      transaction.transactionId !== transactionId ||
      transaction.productId !== PRODUCT_ID ||
      transaction.bundleId !== BUNDLE_ID ||
      transaction.environment !== environment ||
      transaction.type !== "Non-Consumable" ||
      transaction.revocationDate != null
    ) {
      throw new HttpError(
        403,
        "The App Store transaction is not valid for this unlock",
      );
    }
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
        source: "app_store",
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
        `Could not grant App Store entitlement (${grantError.code})`,
      );
      throw new HttpError(500, "Could not save the verified purchase");
    }

    return jsonResponse({ granted: true, environment });
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error(
      `App Store verification failed (${
        error instanceof Error ? error.name : "unknown"
      })`,
    );
    return jsonResponse(
      { error: "Could not verify the App Store purchase" },
      500,
    );
  }
});
