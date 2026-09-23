-- ============================================================
-- DiscipleTrack - Local development seed
-- ============================================================
--
-- Runs after migrations during `npx supabase db reset`, as the
-- postgres superuser. LOCAL DEVELOPMENT ONLY. It never runs on a
-- hosted project; use tool/bootstrap_church.ps1 there.
--
-- Creates the initial trusted user directly in Supabase Auth, then
-- provisions the church through private.bootstrap_church()
-- (DATABASE_CONSTRAINTS.md section 0). All provisioning logic lives
-- in that function; this file only supplies local inputs.
--
-- Local credentials (also listed in config/README.md):
--
--   email      admin@discipletrack.local
--   password   dev-password-123
--   join code  7QK4MZP2XR
--
-- The join code is a fixed, random-looking value that conforms to
-- the production format so the client normalisation path is
-- exercised exactly as in production. Real deployments let
-- bootstrap generate the code cryptographically.
--
-- The auth.users row shape mirrors what GoTrue writes for an email
-- signup. The token columns are '' rather than NULL because GoTrue
-- scans them as strings on sign-in. confirmed_at and identities.email
-- are generated columns and are not inserted.
-- ============================================================

do $$
declare
  v_user_id   constant uuid := 'a0000000-0000-4000-8000-000000000001';
  v_church_id constant uuid := 'c0000000-0000-4000-8000-000000000001';
  v_email     constant text := 'admin@discipletrack.local';
  v_password  constant text := 'dev-password-123';
  v_full_name constant text := 'Dev Admin';
begin
  if not exists (select 1 from auth.users u where u.id = v_user_id) then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      is_sso_user, is_anonymous
    )
    values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt(v_password, extensions.gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'full_name', v_full_name,
        'email_verified', true,
        'phone_verified', false
      ),
      now(), now(),
      '', '', '', '',
      false, false
    );

    -- The on_auth_user_created trigger (Migration 002) has now created
    -- the profiles row from full_name.

    insert into auth.identities (
      provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    )
    values (
      v_user_id::text,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      now(), now(), now()
    );
  end if;

  perform private.bootstrap_church(
    p_church_id       => v_church_id,
    p_name            => 'Bankal Seventh-day Adventist Church',
    p_initial_user_id => v_user_id,
    p_join_code       => '7QK4MZP2XR'
  );
end
$$;
