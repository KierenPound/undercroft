-- Add pet-related columns to the sections table.
-- Used by the Pets dashboard: a free-form notes about the pets, plus the
-- owner's preferred vet (name, phone, URL).

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS pet_notes text NOT NULL DEFAULT '';

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS vet_name text NOT NULL DEFAULT 'Tower vets';

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS vet_phone text NOT NULL DEFAULT '01738 583083';

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS vet_url text NOT NULL DEFAULT
        'https://ivc.co.uk/find-a-vet/tower-vets-perth?utm_source=gmb&utm_medium=organic&utm_campaign=attribute';
