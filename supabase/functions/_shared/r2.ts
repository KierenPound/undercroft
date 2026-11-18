import { AwsClient } from "npm:aws4fetch@1.0.20";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SAFE_PATH_PATTERN = /^[A-Za-z0-9._/-]+$/;

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export interface CallerContext {
  db: SupabaseClient;
}

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: CORS_HEADERS,
  });
}

export async function handleR2Request(
  request: Request,
  handler: (
    context: CallerContext,
    body: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const context = await authenticateCaller(request);
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      throw new HttpError(400, "Request body must be valid JSON");
    }
    if (
      body === null || typeof body !== "object" || Array.isArray(body)
    ) {
      throw new HttpError(400, "Request body must be a JSON object");
    }

    return jsonResponse(
      await handler(context, body as Record<string, unknown>),
    );
  } catch (error) {
    if (error instanceof HttpError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error("R2 endpoint failed");
    return jsonResponse({ error: "Internal server error" }, 500);
  }
}

async function authenticateCaller(request: Request): Promise<CallerContext> {
  const authorization = request.headers.get("Authorization");
  if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
    throw new HttpError(401, "Authentication required");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    throw new HttpError(500, "Supabase authentication is not configured");
  }

  const db = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await db.auth.getUser();
  if (error || !data.user) {
    throw new HttpError(401, "Invalid or expired authentication token");
  }

  return { db };
}

export async function requireEstateAccess(
  context: CallerContext,
  estateId: string,
  ownerOnly: boolean,
): Promise<void> {
  const { data, error } = ownerOnly
    ? await context.db.rpc("get_allowed_estate_ids", {
      requested_role: "owner",
    })
    : await context.db.rpc("get_allowed_estate_ids");

  if (error || !Array.isArray(data)) {
    throw new HttpError(500, "Could not verify estate access");
  }

  const allowedIds = new Set(
    (data as string[]).map((id) => id.toLowerCase()),
  );
  if (!allowedIds.has(estateId.toLowerCase())) {
    throw new HttpError(403, "You do not have access to this estate");
  }
}

export function validateEstateId(value: unknown): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new HttpError(400, "estateId must be a UUID");
  }
  return value.toLowerCase();
}

export function validateRelativePath(value: unknown): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 987 ||
    value.startsWith("/") ||
    value.includes("\\") ||
    value.includes("..") ||
    !SAFE_PATH_PATTERN.test(value)
  ) {
    throw new HttpError(400, "relativePath is invalid");
  }

  const segments = value.split("/");
  if (segments.some((part) => part.length === 0 || part === ".")) {
    throw new HttpError(400, "relativePath is invalid");
  }
  return value;
}

export function validateObjectKey(value: unknown): {
  estateId: string;
  key: string;
} {
  if (typeof value !== "string" || value.length > 1024) {
    throw new HttpError(400, "key is invalid");
  }
  const separator = value.indexOf("/");
  if (separator <= 0) {
    throw new HttpError(400, "key must start with an estate UUID");
  }

  const estateId = validateEstateId(value.slice(0, separator));
  const relativePath = validateRelativePath(value.slice(separator + 1));
  return { estateId, key: `${estateId}/${relativePath}` };
}

export interface R2Client {
  aws: AwsClient;
  bucket: string;
  endpoint: string;
}

export function createR2Client(): R2Client {
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");

  if (
    !accessKeyId || !secretAccessKey ||
    !accountId || !/^[a-f0-9]{32}$/i.test(accountId) ||
    !bucket || !/^[a-z0-9][a-z0-9.-]*[a-z0-9]$/i.test(bucket)
  ) {
    throw new HttpError(500, "R2 is not configured");
  }

  return {
    aws: new AwsClient({
      accessKeyId,
      secretAccessKey,
      region: "auto",
      retries: 0,
      service: "s3",
    }),
    bucket,
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  };
}

function encodedPath(value: string): string {
  return value.split("/").map((segment) => encodeURIComponent(segment)).join(
    "/",
  );
}

export function objectUrl(r2: R2Client, key: string): URL {
  return new URL(
    `${r2.endpoint}/${encodeURIComponent(r2.bucket)}/${encodedPath(key)}`,
  );
}

export function bucketUrl(r2: R2Client): URL {
  return new URL(`${r2.endpoint}/${encodeURIComponent(r2.bucket)}`);
}

export async function presignObjectUrl(
  r2: R2Client,
  method: "GET" | "PUT",
  key: string,
  expiresInSeconds: number,
  contentType?: string,
): Promise<string> {
  const url = objectUrl(r2, key);
  url.searchParams.set("X-Amz-Expires", String(expiresInSeconds));
  const headers = contentType ? { "Content-Type": contentType } : undefined;
  const signedRequest = await r2.aws.sign(
    new Request(url, { headers, method }),
    { aws: { allHeaders: true, signQuery: true } },
  );
  return signedRequest.url.toString();
}

export async function signedR2Fetch(
  r2: R2Client,
  url: URL,
  init: RequestInit,
): Promise<Response> {
  try {
    const response = await r2.aws.fetch(url, init);
    if (!response.ok) {
      throw new HttpError(502, "R2 request failed");
    }
    return response;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(502, "Could not reach R2");
  }
}

export function decodeXml(value: string): string {
  return value.replace(
    /&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi,
    (entity, name: string) => {
      if (name[0] === "#") {
        const codePoint = name[1]?.toLowerCase() === "x"
          ? Number.parseInt(name.slice(2), 16)
          : Number.parseInt(name.slice(1), 10);
        return Number.isFinite(codePoint)
          ? String.fromCodePoint(codePoint)
          : entity;
      }
      const entities: Record<string, string> = {
        amp: "&",
        apos: "'",
        gt: ">",
        lt: "<",
        quot: '"',
      };
      return entities[name.toLowerCase()] ?? entity;
    },
  );
}

export function xmlElements(xml: string, tag: string): string[] {
  const escapedTag = tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const matcher = new RegExp(
    `<${escapedTag}>([\\s\\S]*?)</${escapedTag}>`,
    "g",
  );
  return [...xml.matchAll(matcher)].map((match) => decodeXml(match[1]));
}
