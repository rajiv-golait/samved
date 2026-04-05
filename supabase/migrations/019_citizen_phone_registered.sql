-- Returns whether an auth user already exists for this phone (digits compared).
-- Used by the citizen app: "Sign in" only sends OTP if true; "Create account" only if false.
-- GRANT to anon allows the check before the user is authenticated.

CREATE OR REPLACE FUNCTION public.citizen_phone_registered(p_phone text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.phone IS NOT NULL
      AND btrim(u.phone) <> ''
      AND regexp_replace(u.phone, '[^0-9]', '', 'g')
        = regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g')
    LIMIT 1
  );
$$;

REVOKE ALL ON FUNCTION public.citizen_phone_registered(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.citizen_phone_registered(text) TO anon, authenticated;

COMMENT ON FUNCTION public.citizen_phone_registered(text) IS
  'True if auth.users has a row with the same phone digits as p_phone (E.164 or local digits).';
