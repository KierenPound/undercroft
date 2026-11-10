-- ---------------------------------------------------------------------------
-- 0032: Read-only estate usage summary view (admin / diagnostics only)
--
-- Purpose: gauge how far each estate/tester has got, using counts and yes/no
-- flags only. No stored values are exposed -- in particular the sensitive
-- columns are never selected:
--   notify_account_details.sort_code / account_code / other_code
--   about_you.ni_number / chi_number   (exposed only as has_ni / has_chi flags)
--   sections.phone_pin_1/2, computer_password_1/2, wifi_password
--   sections.pet_policy_number / pet_microchip_number
--
-- SECURITY: this view aggregates across ALL estates, so it deliberately runs
-- with the owner's privileges and bypasses RLS. It must therefore never be
-- readable by anon or authenticated -- Supabase's default privileges would
-- otherwise grant SELECT on a new view automatically. Access is restricted to
-- service_role and the postgres role used by the Supabase SQL Editor.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.estate_usage_summary AS
SELECT
    e.id                     AS estate_id,
    e.name                   AS estate_name,
    u.email                  AS owner_email,
    e.process_region         AS region,
    e.created_at::date       AS created,

    -- People
    (SELECT count(*) FROM public.estate_access a
      WHERE a.estate_id = e.id AND a.role = 'executor')                              AS exec_invited,
    (SELECT count(*) FROM public.estate_access a
      WHERE a.estate_id = e.id AND a.role = 'executor' AND a.status = 'accepted')    AS exec_joined,

    -- Personal details: flags only, never the values
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.full_name)  <> '') AS has_name,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.ni_number)  <> '') AS has_ni,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.chi_number) <> '') AS has_chi,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND x.passport_file_size > 0)   AS has_passport,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND x.licence_file_size  > 0)   AS has_licence,

    -- Section depth: how much was actually written
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id)                                AS sections,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND NOT s.is_standard)          AS custom_sections,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.notes)       <> '') AS with_notes,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.letter_text) <> '') AS with_letter,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.songs_csv)   <> '') AS with_songs,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.youtube_url) <> '') AS with_video,

    -- Checklists
    (SELECT count(*) FROM public.checklist_items c JOIN public.sections s ON s.id = c.section_id
      WHERE s.estate_id = e.id)                                                                    AS todos,
    (SELECT count(*) FROM public.checklist_items c JOIN public.sections s ON s.id = c.section_id
      WHERE s.estate_id = e.id AND c.is_completed)                                                 AS todos_done,

    -- Records
    (SELECT count(*) FROM public.documents             d  WHERE d.estate_id  = e.id) AS documents,
    (SELECT count(*) FROM public.who_to_notify         w  WHERE w.estate_id  = e.id) AS who_to_notify,
    (SELECT count(*) FROM public.notify_account_details n
       JOIN public.who_to_notify w ON w.who_to_notify_id = n.who_to_notify_id
      WHERE w.estate_id = e.id)                                                      AS bank_accounts,
    (SELECT count(*) FROM public.funeral_arrangements  f  WHERE f.estate_id  = e.id) AS funeral,
    (SELECT count(*) FROM public.contacts              ct WHERE ct.estate_id = e.id) AS contacts,
    (SELECT count(*) FROM public.tradespeople          tp WHERE tp.estate_id = e.id) AS tradespeople,
    (SELECT count(*) FROM public.utility_details       ud WHERE ud.estate_id = e.id) AS utilities,
    (SELECT count(*) FROM public.ad_hoc_data           ah WHERE ah.estate_id = e.id) AS ad_hoc,

    -- Attachments
    (SELECT count(*) FROM public.attachments at JOIN public.sections s ON s.id = at.section_id
      WHERE s.estate_id = e.id)                                                      AS attachments,
    (SELECT coalesce(sum(at.file_size), 0)
       FROM public.attachments at JOIN public.sections s ON s.id = at.section_id
      WHERE s.estate_id = e.id)                                                      AS attachment_bytes,

    -- Recency: last edit anywhere in the estate
    GREATEST(
        (SELECT max(s.updated_at) FROM public.sections s WHERE s.estate_id = e.id),
        e.created_at
    )::date                                                                          AS last_activity

FROM public.estates e
JOIN auth.users u ON u.id = e.owner_id;

-- Admin-only: never expose this to anon/authenticated (it spans all estates).
REVOKE ALL ON public.estate_usage_summary FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.estate_usage_summary TO service_role;
