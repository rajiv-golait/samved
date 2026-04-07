-- JE mobile workflow: audit inserts + cross-department + site check-in before full measurement.

-- 1) ticket_events: authenticated users may INSERT only for tickets they can SELECT (RLS on tickets applies).
GRANT INSERT ON public.ticket_events TO authenticated;

DROP POLICY IF EXISTS events_insert_if_ticket_visible ON public.ticket_events;

CREATE POLICY events_insert_if_ticket_visible ON public.ticket_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    actor_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id)
  );

COMMENT ON POLICY events_insert_if_ticket_visible ON public.ticket_events IS
  'Audit trail inserts; EXISTS on tickets is evaluated with caller RLS so JE/citizen/etc. only see allowed rows.';

-- 2) JE may update department_id (cross-assignment UI).
CREATE OR REPLACE FUNCTION public.fn_guard_ticket_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role user_role;
  v_old_rest tickets%ROWTYPE;
  v_new_rest tickets%ROWTYPE;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();

  IF v_caller_role IN ('city_engineer', 'commissioner', 'super_admin') THEN
    RETURN NEW;
  END IF;

  IF OLD.ticket_ref IS DISTINCT FROM NEW.ticket_ref THEN
    RAISE EXCEPTION 'ticket_ref is system-generated and immutable';
  END IF;
  IF OLD.zone_id IS DISTINCT FROM NEW.zone_id THEN
    RAISE EXCEPTION 'zone_id is system-routed and immutable';
  END IF;
  IF OLD.prabhag_id IS DISTINCT FROM NEW.prabhag_id THEN
    RAISE EXCEPTION 'prabhag_id is system-routed and immutable';
  END IF;
  IF OLD.assigned_je IS DISTINCT FROM NEW.assigned_je THEN
    RAISE EXCEPTION 'assigned_je is system-assigned and immutable';
  END IF;
  IF OLD.location IS DISTINCT FROM NEW.location
     OR OLD.latitude IS DISTINCT FROM NEW.latitude
     OR OLD.longitude IS DISTINCT FROM NEW.longitude THEN
    RAISE EXCEPTION 'Ticket location data is immutable after creation';
  END IF;

  v_old_rest := OLD;
  v_new_rest := NEW;
  v_old_rest.updated_at := NULL;
  v_new_rest.updated_at := NULL;

  IF v_caller_role = 'citizen' THEN
    v_old_rest.citizen_confirmed := NULL;
    v_new_rest.citizen_confirmed := NULL;
    v_old_rest.citizen_rating := NULL;
    v_new_rest.citizen_rating := NULL;
    v_old_rest.citizen_confirm_at := NULL;
    v_new_rest.citizen_confirm_at := NULL;
    IF v_old_rest IS DISTINCT FROM v_new_rest THEN
      RAISE EXCEPTION 'Citizens can only update feedback fields (citizen_confirmed, citizen_rating)';
    END IF;
    RETURN NEW;
  END IF;

  IF v_caller_role IN ('contractor', 'mukadam') THEN
    v_old_rest.photo_after := NULL;
    v_new_rest.photo_after := NULL;
    v_old_rest.status := NULL;
    v_new_rest.status := NULL;
    IF v_old_rest IS DISTINCT FROM v_new_rest THEN
      RAISE EXCEPTION 'Field executors (Contractor/Mukadam) can only update photo_after and status (to audit_pending)';
    END IF;
    RETURN NEW;
  END IF;

  IF v_caller_role = 'je' THEN
    v_old_rest.status := NULL;
    v_new_rest.status := NULL;
    v_old_rest.photo_je_inspection := NULL;
    v_new_rest.photo_je_inspection := NULL;
    v_old_rest.department_note := NULL;
    v_new_rest.department_note := NULL;
    v_old_rest.damage_cause := NULL;
    v_new_rest.damage_cause := NULL;

    IF OLD.status NOT IN ('open', 'verified') AND (
         OLD.work_type IS DISTINCT FROM NEW.work_type OR
         OLD.dimensions IS DISTINCT FROM NEW.dimensions OR
         OLD.rate_per_unit IS DISTINCT FROM NEW.rate_per_unit OR
         OLD.estimated_cost IS DISTINCT FROM NEW.estimated_cost OR
         OLD.rate_card_id IS DISTINCT FROM NEW.rate_card_id OR
         OLD.assigned_contractor IS DISTINCT FROM NEW.assigned_contractor OR
         OLD.assigned_mukadam IS DISTINCT FROM NEW.assigned_mukadam
       ) THEN
      RAISE EXCEPTION 'Economic details and assignments are locked after the ticket leaves the verification phase';
    END IF;

    v_old_rest.work_type := NULL;
    v_new_rest.work_type := NULL;
    v_old_rest.dimensions := NULL;
    v_new_rest.dimensions := NULL;
    v_old_rest.rate_per_unit := NULL;
    v_new_rest.rate_per_unit := NULL;
    v_old_rest.estimated_cost := NULL;
    v_new_rest.estimated_cost := NULL;
    v_old_rest.assigned_contractor := NULL;
    v_new_rest.assigned_contractor := NULL;
    v_old_rest.assigned_mukadam := NULL;
    v_new_rest.assigned_mukadam := NULL;
    v_old_rest.rate_card_id := NULL;
    v_new_rest.rate_card_id := NULL;
    v_old_rest.department_id := NULL;
    v_new_rest.department_id := NULL;

    IF v_old_rest IS DISTINCT FROM v_new_rest THEN
      RAISE EXCEPTION 'JE can only update workflow state, verify dimensions/cost, assign executors, and cross-assign department';
    END IF;
    RETURN NEW;
  END IF;

  IF v_caller_role IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
    v_old_rest.status := NULL;
    v_new_rest.status := NULL;
    IF v_old_rest IS DISTINCT FROM v_new_rest THEN
      RAISE EXCEPTION 'Zone officers can only update ticket status';
    END IF;
    RETURN NEW;
  END IF;

  IF v_caller_role = 'accounts' THEN
    v_old_rest.bill_id := NULL;
    v_new_rest.bill_id := NULL;
    v_old_rest.status := NULL;
    v_new_rest.status := NULL;
    IF v_old_rest IS DISTINCT FROM v_new_rest THEN
      RAISE EXCEPTION 'Accounts can only update bill_id and billing status';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- 3) Allow open -> verified after JE GPS check-in (dimensions/rate filled on next screen).
CREATE OR REPLACE FUNCTION public.fn_validate_ticket_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role user_role;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();

    IF v_caller_role IN ('city_engineer', 'commissioner', 'super_admin') THEN
      RETURN NEW;
    END IF;

    CASE OLD.status
      WHEN 'open' THEN
        IF NEW.status NOT IN ('verified', 'rejected', 'cross_assigned', 'escalated') THEN
          RAISE EXCEPTION 'From open, ticket can only move to verified, rejected, cross_assigned, or escalated';
        END IF;
        IF NEW.status = 'verified'
           AND NEW.je_checkin_time IS NULL
           AND (NEW.dimensions IS NULL OR NEW.rate_per_unit IS NULL) THEN
          RAISE EXCEPTION 'Ticket must have verified dimensions and rate to move to verified, or complete JE site check-in first';
        END IF;
        IF NEW.status = 'escalated'
           AND v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can escalate an open ticket';
        END IF;

      WHEN 'verified' THEN
        IF NEW.status NOT IN ('assigned', 'escalated') THEN
          RAISE EXCEPTION 'From verified, ticket can only move to assigned or escalated';
        END IF;
        IF NEW.status = 'assigned' AND (NEW.assigned_contractor IS NULL) = (NEW.assigned_mukadam IS NULL) THEN
          RAISE EXCEPTION 'Ticket must have exactly one executor (contractor OR mukadam) to be marked assigned';
        END IF;
        IF NEW.status = 'escalated'
           AND v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can escalate a verified ticket';
        END IF;

      WHEN 'assigned' THEN
        IF NEW.status NOT IN ('in_progress', 'escalated') THEN
          RAISE EXCEPTION 'From assigned, ticket can only move to in_progress or escalated';
        END IF;
        IF NEW.status = 'escalated'
           AND v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can escalate an assigned ticket';
        END IF;

      WHEN 'in_progress' THEN
        IF NEW.status NOT IN ('audit_pending', 'escalated') THEN
          RAISE EXCEPTION 'From in_progress, ticket can only move to audit_pending or escalated';
        END IF;
        IF NEW.status = 'audit_pending' AND NEW.photo_after IS NULL THEN
          RAISE EXCEPTION 'Cannot submit for audit without an after-photo';
        END IF;
        IF NEW.status = 'escalated'
           AND v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can escalate an in-progress ticket';
        END IF;

      WHEN 'audit_pending' THEN
        IF NEW.status NOT IN ('resolved', 'in_progress', 'escalated') THEN
          RAISE EXCEPTION 'From audit_pending, ticket can only move to resolved, back to in_progress, or escalated';
        END IF;
        IF NEW.status = 'resolved' AND NEW.ssim_pass IS NOT TRUE AND NEW.citizen_confirmed IS NOT TRUE THEN
          RAISE EXCEPTION 'Ticket cannot be resolved without passing SSIM verification or citizen confirmation';
        END IF;
        IF NEW.status = 'escalated'
           AND v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can escalate an audit-pending ticket';
        END IF;

      WHEN 'resolved' THEN
        RAISE EXCEPTION 'Ticket is resolved and cannot change state';

      WHEN 'rejected' THEN
        RAISE EXCEPTION 'Ticket is rejected and cannot change state';

      WHEN 'cross_assigned' THEN
        RAISE EXCEPTION 'Ticket is cross-assigned and cannot change state';

      WHEN 'escalated' THEN
        IF v_caller_role NOT IN ('ae', 'de', 'ee', 'assistant_commissioner') THEN
          RAISE EXCEPTION 'Only AE, EE, or Assistant Commissioner can move an escalated ticket back into workflow';
        END IF;
        IF NEW.status NOT IN ('verified', 'assigned', 'in_progress', 'audit_pending', 'resolved') THEN
          RAISE EXCEPTION 'From escalated, ticket can only move to verified, assigned, in_progress, audit_pending, or resolved';
        END IF;
        IF NEW.status IN ('verified', 'assigned')
           AND (NEW.dimensions IS NULL OR NEW.rate_per_unit IS NULL) THEN
          RAISE EXCEPTION 'Escalated ticket needs verified dimensions and rate before re-entering workflow';
        END IF;
        IF NEW.status = 'assigned' AND (NEW.assigned_contractor IS NULL) = (NEW.assigned_mukadam IS NULL) THEN
          RAISE EXCEPTION 'Escalated ticket needs exactly one executor before moving to assigned';
        END IF;
        IF NEW.status IN ('in_progress', 'audit_pending', 'resolved')
           AND (NEW.assigned_contractor IS NULL) = (NEW.assigned_mukadam IS NULL) THEN
          RAISE EXCEPTION 'Escalated ticket needs exactly one executor before resuming execution';
        END IF;
        IF NEW.status IN ('audit_pending', 'resolved') AND NEW.photo_after IS NULL THEN
          RAISE EXCEPTION 'Escalated ticket needs an after-photo before audit or resolution';
        END IF;
        IF NEW.status = 'resolved'
           AND NEW.ssim_pass IS NOT TRUE
           AND NEW.citizen_confirmed IS NOT TRUE THEN
          RAISE EXCEPTION 'Escalated ticket cannot be resolved without passing SSIM verification or citizen confirmation';
        END IF;

      ELSE
        RAISE EXCEPTION 'Unknown status origin: %', OLD.status;
    END CASE;
  END IF;

  RETURN NEW;
END;
$$;
