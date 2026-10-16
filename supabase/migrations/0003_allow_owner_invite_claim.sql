-- 0003: Allow owner invite codes to be claimed
--
-- The estate_access_claim_pending_invite policy previously only allowed
-- executor invites (role = 'executor') to be claimed. We now also allow
-- co-owner invites (role = 'owner') so an existing owner can invite another
-- person to become a co-owner of the same estate.

DROP POLICY IF EXISTS estate_access_claim_pending_invite ON public.estate_access;

CREATE POLICY estate_access_claim_pending_invite ON public.estate_access
    FOR UPDATE
    TO authenticated
    USING (
        status = 'pending'
        AND user_id IS NULL
        AND invite_code IS NOT NULL
        AND role IN ('executor', 'owner')
    )
    WITH CHECK (
        status = 'accepted'
        AND user_id = auth.uid()
        AND role IN ('executor', 'owner')
        AND estate_id = estate_id
        AND invite_code = invite_code
        AND invited_email = invited_email
    );
