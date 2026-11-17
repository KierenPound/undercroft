import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
const NOTIFICATION_EMAIL = "support@crabkingslair.com";
const NOTIFICATION_FROM = "contact@crabkingslair.com";

serve(async (req) => {
  try {
    const bodyText = await req.text();
    if (!bodyText) {
      return new Response(JSON.stringify({ success: true, message: "Empty body ignored" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload = JSON.parse(bodyText);

    if (payload.type === "INSERT" && payload.table === "support_tickets") {
      const ticket = payload.record;

      const userEmail = ticket?.user_email || "N/A";
      const userName = ticket?.user_name || "N/A";
      const ticketSubject = ticket?.subject || "No Subject";
      const ticketMessage = ticket?.message || "No Message Provided";
      const screenshot = ticket?.screenshot;

      let screenshotHtml = "";
      if (screenshot && typeof screenshot === "string" && screenshot.startsWith("data:")) {
        screenshotHtml = `
          <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #e5e7eb;">
            <p style="margin: 0 0 8px 0; color: #4b5563; font-weight: bold;">Attached Screenshot:</p>
            <img src="${screenshot}" alt="Ticket Screenshot" style="max-width: 100%; height: auto; border: 1px solid #d1d5db; border-radius: 6px;" />
          </div>
        `;
      }

      const htmlContent = `
        <div style="font-family: Arial, sans-serif; background-color: #f4f4f7; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 24px; border: 1px solid #e5e7eb;">
            <h2 style="color: #111827; margin-top: 0;">New Support Ticket Received</h2>
            
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
              <tr>
                <td style="padding: 6px 0; color: #6b7280; width: 100px;"><strong>From:</strong></td>
                <td style="padding: 6px 0; color: #111827;">${userName} (&lt;<a href="mailto:${userEmail}">${userEmail}</a>&gt;)</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; color: #6b7280;"><strong>Subject:</strong></td>
                <td style="padding: 6px 0; color: #111827; font-weight: bold;">${ticketSubject}</td>
              </tr>
            </table>

            <div style="background-color: #f9fafb; padding: 12px 16px; border-left: 4px solid #2563eb; border-radius: 4px; margin-bottom: 16px;">
              <p style="margin: 0; white-space: pre-wrap; color: #374151;">${ticketMessage}</p>
            </div>

            ${screenshotHtml}
          </div>
        </div>
      `;

      // Note: Brevo requires the sender email to be verified on your Brevo account.
      // Using kieren@hotmail.co.uk or your verified Brevo sender domain.
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "api-key": BREVO_API_KEY!,
        },
        body: JSON.stringify({
          sender: { name: "Support Alerts", email: NOTIFICATION_FROM },
          to: [{ email: NOTIFICATION_EMAIL }],
          replyTo: { email: userEmail, name: userName },
          subject: `[Support Ticket] ${ticketSubject}`,
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
