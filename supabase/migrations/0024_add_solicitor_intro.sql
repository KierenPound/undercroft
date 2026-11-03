-- 0024: Add editable intro copy for the Legal Documents wills card
--
-- This stores the sentence shown beneath the "Wills & Codicils" heading so
-- owners can tailor the wording per estate.

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS solicitor_intro text NOT NULL DEFAULT '';

UPDATE public.sections
SET solicitor_intro = 'The solicitors hold the master documents.'
WHERE title = 'Legal Documents'
  AND solicitor_intro = '';
