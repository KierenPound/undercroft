import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Runs inside the UnderCroft project, so the URL comes from the environment.
// SUPABASE_SECRET_KEY is the sb_secret_... key; SUPABASE_SERVICE_ROLE_KEY is
// the legacy fallback for projects that still inject it.
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseSecretKey = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const cronSecret = Deno.env.get("CRON_SECRET");
const brevoApiKey = Deno.env.get("BREVO_API_KEY");
const reminderFromEmail = Deno.env.get("REMINDER_FROM_EMAIL");

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!cronSecret || request.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  if (!supabaseUrl || !supabaseSecretKey || !brevoApiKey || !reminderFromEmail) {
    console.error("Reminder function is missing required configuration");
    return jsonResponse({ error: "Reminder service is not configured" }, 500);
  }

  const db = createClient(supabaseUrl, supabaseSecretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: queueError } = await db.rpc(
    "queue_due_estate_review_reminders",
  );
  if (queueError) {
    console.error("Could not queue due reminders");
    return jsonResponse({ error: "Could not queue reminders" }, 500);
  }

  const { data: reminders, error: claimError } = await db.rpc(
    "claim_estate_review_reminders",
    { batch_size: 50 },
  );
  if (claimError || !reminders) {
    console.error("Could not claim reminder batch");
    return jsonResponse({ error: "Could not claim reminders" }, 500);
  }

  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const reminder of reminders) {
    const { data: userResult, error: userError } = await db.auth.admin
      .getUserById(reminder.owner_user_id);

    if (userError) {
      await db
        .from("estate_review_reminder_sends")
        .update({
          status: "pending",
          updated_at: new Date().toISOString(),
          last_error: "Could not load owner email",
        })
        .eq("id", reminder.id);
      failed++;
      continue;
    }

    const email = userResult.user?.email;
    if (!email) {
      await db
        .from("estate_review_reminder_sends")
        .update({
          status: "skipped",
          updated_at: new Date().toISOString(),
          last_error: null,
        })
        .eq("id", reminder.id);
      skipped++;
      continue;
    }

    const htmlContent = `
      <div style="font-family:Arial,sans-serif;color:#26332d;line-height:1.6">
        <h2 style="font-weight:600">A yearly reminder from UnderCroft</h2>
        <p>Please open UnderCroft on your device and review your estate
        information. Go to Readiness and tap "I have checked my details" when
        you have finished.</p>
        <p style="font-size:13px;color:#65716a">
          You can turn off these annual reminders in Settings.
        </p>
      </div>`;

    try {
      const response = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "api-key": brevoApiKey,
        },
        body: JSON.stringify({
          sender: { name: "UnderCroft", email: reminderFromEmail },
          to: [{ email }],
          subject: "A yearly reminder from UnderCroft",
          htmlContent,
          textContent:
            `Please open UnderCroft on your device and review your estate ` +
            `information. Go to Readiness and tap "I have checked my details" ` +
            `when you have finished.\n\n` +
            `You can turn off these annual reminders in Settings.`,
        }),
      });

      if (!response.ok) {
        console.error(
          `Brevo rejected a reminder with status ${response.status}`,
        );
        await db
          .from("estate_review_reminder_sends")
          .update({
            status: "pending",
            updated_at: new Date().toISOString(),
            last_error: `Brevo request failed (${response.status})`,
          })
          .eq("id", reminder.id);
        failed++;
        continue;
      }

      const { error: updateError } = await db
        .from("estate_review_reminder_sends")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          last_error: null,
        })
        .eq("id", reminder.id);

      if (updateError) {
        console.error("Email sent but send status could not be updated");
        failed++;
      } else {
        sent++;
      }
    } catch {
      await db
        .from("estate_review_reminder_sends")
        .update({
          status: "pending",
          updated_at: new Date().toISOString(),
          last_error: "Brevo request could not be completed",
        })
        .eq("id", reminder.id);
      failed++;
    }
  }

  return jsonResponse({ sent, skipped, failed });
});
