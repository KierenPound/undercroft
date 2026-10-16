-- ============================================================================
-- UnderCroft: Allow executors to toggle checklist items
--
-- Previously only estate owners could UPDATE checklist_items. Since the
-- executor is the person who actually works through the checklist, both
-- owners and executors may now toggle items on/off.
--
-- INSERT and DELETE remain owner-only (only owners can add/remove items).
-- ============================================================================

DROP POLICY IF EXISTS checklist_items_owner_update ON public.checklist_items;

CREATE POLICY checklist_items_linked_update ON public.checklist_items
    FOR UPDATE
    TO authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    )
    WITH CHECK (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    );
