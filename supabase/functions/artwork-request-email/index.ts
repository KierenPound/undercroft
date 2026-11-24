import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
const NOTIFICATION_EMAIL = "support@undercroftvault.com";
const NOTIFICATION_FROM = "support@undercroftvault.com";

serve(async (req) => {
  try {
    const bodyText = await req.text();
    if (!bodyText) {
      return new Response(JSON.stringify({ success: true, message: "Empty body ignored" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload = JSON.parse(bodyText);

    if (payload.type === "INSERT" && payload.table === "requests") {
      const request = payload.record;

      const cardName = request?.card_name || "Unknown Card";
      const customerName = request?.name || "N/A";
      const customerEmail = request?.email || "N/A";
      const customerMobile = request?.mobile || "N/A";
      const artworkType = request?.artwork_type || "N/A";
      const notes = request?.notes || "No additional notes provided.";

      const htmlContent = `
        <div style="font-family: Arial, sans-serif; background-color: #f4f4f7; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 24px; border: 1px solid #e5e7eb;">
            <h2 style="color: #111827; margin-top: 0;">New Artwork Request Received</h2>

            <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
              <tr>
                <td style="padding: 6px 0; color: #6b7280; width: 120px;"><strong>Card Name:</strong></td>
                <td style="padding: 6px 0; color: #111827; font-weight: bold; font-size: 16px;">${cardName}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; color: #6b7280;"><strong>Artwork Type:</strong></td>
                <td style="padding: 6px 0; color: #2563eb; font-weight: bold;">${artworkType}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; color: #6b7280;"><strong>Customer:</strong></td>
                <td style="padding: 6px 0; color: #111827;">${customerName}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; color: #6b7280;"><strong>Email:</strong></td>
                <td style="padding: 6px 0; color: #111827;"><a href="mailto:${customerEmail}">${customerEmail}</a></td>
              </tr>
              <tr>
                <td style="padding: 6px 0; color: #6b7280;"><strong>Mobile:</strong></td>
                <td style="padding: 6px 0; color: #111827;"><a href="tel:${customerMobile}">${customerMobile}</a></td>
              </tr>
            </table>

            <div style="margin-top: 12px;">
              <p style="margin: 0 0 6px 0; color: #4b5563; font-weight: bold;">Customer Notes:</p>
              <div style="background-color: #f9fafb; padding: 12px 16px; border-left: 4px solid #2563eb; border-radius: 4px;">
                <p style="margin: 0; white-space: pre-wrap; color: #374151;">${notes}</p>
              </div>
            </div>
          </div>
        </div>
      `;

      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "api-key": BREVO_API_KEY!,
        },
        body: JSON.stringify({
          sender: { name: "Crab Kings Lair Requests", email: NOTIFICATION_FROM },
          to: [{ email: NOTIFICATION_EMAIL }],
          replyTo: customerEmail !== "N/A" ? { email: customerEmail, name: customerName } : undefined,
          subject: `[New Request] ${cardName} (${artworkType})`,
          htmlContent: htmlContent,
        }),
      });

      if (!res.ok) {
        const errorText = await res.text();
        console.error("Brevo API Error Response:", errorText);
        throw new Error(`Brevo API Error: ${errorText}`);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Edge Function Caught Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
