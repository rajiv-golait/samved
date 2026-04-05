-- PostgREST upsert (INSERT .. ON CONFLICT) requires INSERT + UPDATE on profiles.
-- Migration 014 only granted SELECT, UPDATE. Allow citizens to insert their own row
-- if a client still uses upsert or the auth trigger is temporarily absent.

GRANT INSERT ON public.profiles TO authenticated;

CREATE POLICY profiles_insert_own_citizen ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id
    AND role = 'citizen'::public.user_role
  );

COMMENT ON POLICY profiles_insert_own_citizen ON public.profiles IS
  'Citizen self-registration row; blocks setting non-citizen role on insert.';
