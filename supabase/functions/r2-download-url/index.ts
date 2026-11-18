import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createR2Client,
  handleR2Request,
  presignObjectUrl,
  requireEstateAccess,
  validateObjectKey,
} from "../_shared/r2.ts";

serve((request) =>
  handleR2Request(request, async (context, body) => {
    const { estateId, key } = validateObjectKey(body.key);
    await requireEstateAccess(context, estateId, false);

    const url = await presignObjectUrl(
      createR2Client(),
      "GET",
      key,
      3600,
    );
    return { url };
  })
);
