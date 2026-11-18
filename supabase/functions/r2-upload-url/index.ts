import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createR2Client,
  handleR2Request,
  HttpError,
  presignObjectUrl,
  requireEstateAccess,
  validateEstateId,
  validateRelativePath,
} from "../_shared/r2.ts";

const ALLOWED_CONTENT_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/heic",
  "text/plain",
  "video/mp4",
  "video/quicktime",
  "video/x-m4v",
  "video/3gpp",
  "video/webm",
]);
const MAX_SIZE_BYTES = 157286400;

serve((request) =>
  handleR2Request(request, async (context, body) => {
    const estateId = validateEstateId(body.estateId);
    const relativePath = validateRelativePath(body.relativePath);
    if (
      typeof body.contentType !== "string" ||
      !ALLOWED_CONTENT_TYPES.has(body.contentType)
    ) {
      throw new HttpError(400, "contentType is not allowed");
    }
    if (
      typeof body.sizeBytes !== "number" ||
      !Number.isSafeInteger(body.sizeBytes) ||
      body.sizeBytes < 0 ||
      body.sizeBytes > MAX_SIZE_BYTES
    ) {
      throw new HttpError(
        400,
        "sizeBytes must be between 0 and 157286400",
      );
    }

    await requireEstateAccess(context, estateId, true);

    const key = `${estateId}/${relativePath}`;
    const uploadUrl = await presignObjectUrl(
      createR2Client(),
      "PUT",
      key,
      900,
      body.contentType,
    );
    return { key, uploadUrl };
  })
);
