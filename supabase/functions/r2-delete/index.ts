import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  bucketUrl,
  createR2Client,
  handleR2Request,
  HttpError,
  objectUrl,
  requireEstateAccess,
  signedR2Fetch,
  validateEstateId,
  validateObjectKey,
  xmlElements,
} from "../_shared/r2.ts";

const DELETE_CONCURRENCY = 25;

async function deleteKeys(
  r2: ReturnType<typeof createR2Client>,
  keys: string[],
): Promise<void> {
  for (let offset = 0; offset < keys.length; offset += DELETE_CONCURRENCY) {
    const batch = keys.slice(offset, offset + DELETE_CONCURRENCY);
    await Promise.all(
      batch.map((key) =>
        signedR2Fetch(r2, objectUrl(r2, key), { method: "DELETE" })
      ),
    );
  }
}

async function deleteEstateObjects(
  r2: ReturnType<typeof createR2Client>,
  estateId: string,
): Promise<number> {
  const prefix = `${estateId}/`;
  const seenTokens = new Set<string>();
  let continuationToken: string | undefined;
  let deleted = 0;

  do {
    const url = bucketUrl(r2);
    url.searchParams.set("list-type", "2");
    url.searchParams.set("max-keys", "1000");
    url.searchParams.set("prefix", prefix);
    if (continuationToken) {
      url.searchParams.set("continuation-token", continuationToken);
    }

    const response = await signedR2Fetch(r2, url, { method: "GET" });
    const xml = await response.text();
    const keys = xmlElements(xml, "Key");
    if (keys.some((key) => !key.startsWith(prefix))) {
      throw new HttpError(502, "R2 returned an object outside the estate");
    }

    await deleteKeys(r2, keys);
    deleted += keys.length;

    const isTruncated = xmlElements(xml, "IsTruncated")[0] === "true";
    const nextToken = xmlElements(xml, "NextContinuationToken")[0];
    if (!isTruncated) break;
    if (!nextToken || seenTokens.has(nextToken)) {
      throw new HttpError(502, "R2 pagination did not advance");
    }
    seenTokens.add(nextToken);
    continuationToken = nextToken;
  } while (continuationToken);

  return deleted;
}

serve((request) =>
  handleR2Request(request, async (context, body) => {
    if ("keys" in body) {
      if (body.deleteAll === true || !Array.isArray(body.keys)) {
        throw new HttpError(400, "Provide keys or estateId with deleteAll");
      }
      if (body.keys.length === 0 || body.keys.length > 10000) {
        throw new HttpError(400, "keys must contain between 1 and 10000 items");
      }

      const parsed = body.keys.map(validateObjectKey);
      const estateIds = [...new Set(parsed.map((entry) => entry.estateId))];
      for (const estateId of estateIds) {
        await requireEstateAccess(context, estateId, true);
      }

      const keys = [...new Set(parsed.map((entry) => entry.key))];
      await deleteKeys(createR2Client(), keys);
      return { deleted: keys.length };
    }

    if (body.deleteAll !== true) {
      throw new HttpError(400, "Provide keys or estateId with deleteAll");
    }
    const estateId = validateEstateId(body.estateId);
    await requireEstateAccess(context, estateId, true);

    const deleted = await deleteEstateObjects(createR2Client(), estateId);
    return { deleted };
  })
);
