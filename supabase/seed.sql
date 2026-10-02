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
    p_name            => 'Liberty Bible Baptist Church - Gensan',
    p_initial_user_id => v_user_id,
    p_join_code       => '7QK4MZP2XR'
  );
end
$$;


-- ============================================================
-- Ministry structure (Vertical Slice 3)
-- ============================================================
--
-- Five more accounts, all ACTIVE with onboarding complete, password
-- dev-password-123:
--
--   leader@discipletrack.local      Leader of "Young Adults A"
--   discipler@discipletrack.local   Discipler, paired with disciple1
--   disciple1@discipletrack.local   Disciple, paired
--   disciple2@discipletrack.local   Disciple, not paired
--   member@discipletrack.local      unplaced, with a pending invitation
--                                   to accept by hand
--
-- Everything after the auth rows goes through the real controlled
-- operations, with each account impersonated by setting
-- request.jwt.claims (which is what auth.uid() reads), so the seeded
-- state is one the app itself could have produced: join request,
-- approval by the admin, first-entry completion, group creation,
-- invitations, acceptances and pairing.

do $$
declare
  v_church_id constant uuid := 'c0000000-0000-4000-8000-000000000001';
  v_admin_id  constant uuid := 'a0000000-0000-4000-8000-000000000001';
  v_join_code constant text := '7QK4MZP2XR';
  v_password  constant text := 'dev-password-123';

  -- id, email, full name, phone
  v_users constant text[][] := array[
    ['a0000000-0000-4000-8000-000000000002', 'leader@discipletrack.local',    'Lea Santos',      '+63 917 555 0102'],
    ['a0000000-0000-4000-8000-000000000003', 'discipler@discipletrack.local', 'Dino Reyes',      '+63 917 555 0103'],
    ['a0000000-0000-4000-8000-000000000004', 'disciple1@discipletrack.local', 'Diana Cruz',      '+63 917 555 0104'],
    ['a0000000-0000-4000-8000-000000000005', 'disciple2@discipletrack.local', 'Daniel Bautista', '+63 917 555 0105'],
    ['a0000000-0000-4000-8000-000000000006', 'member@discipletrack.local',    'Mara Villanueva', '+63 917 555 0106']
  ];

  v_uid        uuid;
  v_email      text;
  v_membership uuid;
  v_group      uuid;
  v_invitation uuid;
  v_discipler  uuid;
  v_disciple1  uuid;
  i            integer;

  -- Membership id of seeded user n (1-based index into v_users).
  v_mids uuid[] := array[]::uuid[];
begin
  if exists (select 1 from public.d_groups g where g.church_id = v_church_id) then
    return;
  end if;

  for i in 1 .. array_length(v_users, 1) loop
    v_uid   := v_users[i][1]::uuid;
    v_email := v_users[i][2];

    if not exists (select 1 from auth.users u where u.id = v_uid) then
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        is_sso_user, is_anonymous
      )
      values (
        '00000000-0000-0000-0000-000000000000',
        v_uid,
        'authenticated',
        'authenticated',
        v_email,
        extensions.crypt(v_password, extensions.gen_salt('bf')),
        now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object(
          'sub', v_uid::text,
          'email', v_email,
          'full_name', v_users[i][3],
          'email_verified', true,
          'phone_verified', false
        ),
        now(), now(),
        '', '', '', '',
        false, false
      );

      insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      )
      values (
        v_uid::text,
        v_uid,
        jsonb_build_object(
          'sub', v_uid::text,
          'email', v_email,
          'email_verified', true,
          'phone_verified', false
        ),
        'email',
        now(), now(), now()
      );
    end if;

    update public.profiles p set phone = v_users[i][4] where p.id = v_uid;

    -- Join request as the user, approval as the admin, first entry as
    -- the user.
    perform set_config('request.jwt.claims', json_build_object('sub', v_uid)::text, true);
    select r.membership_id into v_membership
    from public.request_join_church(v_church_id, v_join_code) r;

    perform set_config('request.jwt.claims', json_build_object('sub', v_admin_id)::text, true);
    perform public.approve_church_membership(v_membership);

    perform set_config('request.jwt.claims', json_build_object('sub', v_uid)::text, true);
    perform public.complete_onboarding();

    v_mids := v_mids || v_membership;
  end loop;

  -- The Coordinator (the bootstrap admin) creates the group with its
  -- Leader.
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin_id)::text, true);
  select r.d_group_id into v_group
  from public.create_d_group(
    'Young Adults A',
    'Seeded for local development.',
    v_mids[1]
  ) r;

  -- The Leader invites the Discipler and both Disciples; each accepts.
  for i in 2 .. 4 loop
    perform set_config('request.jwt.claims', json_build_object('sub', v_users[1][1])::text, true);
    select r.invitation_id into v_invitation
    from public.invite_to_d_group(
      v_group,
      v_mids[i],
      case when i = 2 then 'DISCIPLER' else 'DISCIPLE' end::public.d_group_responsibility
    ) r;

    perform set_config('request.jwt.claims', json_build_object('sub', v_users[i][1])::text, true);
    perform public.respond_to_d_group_invitation(v_invitation, true);
  end loop;

  select dgm.id into v_discipler
  from public.d_group_memberships dgm
  where dgm.church_membership_id = v_mids[2] and dgm.ended_at is null;

  select dgm.id into v_disciple1
  from public.d_group_memberships dgm
  where dgm.church_membership_id = v_mids[3] and dgm.ended_at is null;

  -- The Leader pairs disciple1 with the Discipler and leaves member@
  -- with a pending invitation.
  perform set_config('request.jwt.claims', json_build_object('sub', v_users[1][1])::text, true);
  perform public.set_discipler(v_disciple1, v_discipler);
  perform public.invite_to_d_group(v_group, v_mids[5], 'DISCIPLE');

  perform set_config('request.jwt.claims', '', true);
end
$$;
