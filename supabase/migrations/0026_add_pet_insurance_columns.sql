-- 0026: Add pet insurance and microchip columns to sections
--
-- The "Pets" section records the details an executor would need to look after
-- or rehome the animals: the insurer, the policy number, and the microchip
-- number. An empty string means "not set".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS pet_insurance_company text NOT NULL DEFAULT '';

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS pet_policy_number text NOT NULL DEFAULT '';

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS pet_microchip_number text NOT NULL DEFAULT '';
