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
-- Nine more accounts, all ACTIVE with onboarding complete, password
-- dev-password-123:
--
--   leader@discipletrack.local      Leader of "Young Adults A"
--   discipler@discipletrack.local   Discipler
--   disciple1@discipletrack.local   Disciple
--   disciple2@discipletrack.local   Disciple
--   member@discipletrack.local      unplaced, with a pending invitation
--                                   to accept by hand
--   discipler2@discipletrack.local  Discipler
--   disciple3@discipletrack.local   Disciple
--   disciple4@discipletrack.local   Disciple, never paired
--   disciple5@discipletrack.local   Disciple
--
-- This block places them; the Slice 5 block below pairs them and records
-- their meetings.
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
    ['a0000000-0000-4000-8000-000000000006', 'member@discipletrack.local',    'Mara Villanueva', '+63 917 555 0106'],
    ['a0000000-0000-4000-8000-000000000007', 'discipler2@discipletrack.local', 'Grace Lim',      '+63 917 555 0107'],
    ['a0000000-0000-4000-8000-000000000008', 'disciple3@discipletrack.local', 'Ella Navarro',    '+63 917 555 0108'],
    ['a0000000-0000-4000-8000-000000000009', 'disciple4@discipletrack.local', 'Felix Ramos',     '+63 917 555 0109'],
    ['a0000000-0000-4000-8000-00000000000a', 'disciple5@discipletrack.local', 'Hana Torres',     '+63 917 555 0110']
  ];

  v_uid        uuid;
  v_email      text;
  v_membership uuid;
  v_group      uuid;
  v_invitation uuid;
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

  -- The Leader invites both Disciplers and every Disciple; each accepts.
  foreach i in array array[2, 3, 4, 6, 7, 8, 9] loop
    perform set_config('request.jwt.claims', json_build_object('sub', v_users[1][1])::text, true);
    select r.invitation_id into v_invitation
    from public.invite_to_d_group(
      v_group,
      v_mids[i],
      case when i in (2, 6) then 'DISCIPLER' else 'DISCIPLE' end::public.d_group_responsibility
    ) r;

    perform set_config('request.jwt.claims', json_build_object('sub', v_users[i][1])::text, true);
    perform public.respond_to_d_group_invitation(v_invitation, true);
  end loop;

  -- The Leader leaves member@ with a pending invitation.
  perform set_config('request.jwt.claims', json_build_object('sub', v_users[1][1])::text, true);
  perform public.invite_to_d_group(v_group, v_mids[5], 'DISCIPLE');

  perform set_config('request.jwt.claims', '', true);
end
$$;


-- ============================================================
-- Discipleship meetings and progress (Vertical Slice 5)
-- ============================================================
--
-- Representative states for looking at Journey, My Disciples, Disciple
-- detail, Record a meeting, Home and Profile by hand. Not test
-- fixtures: integration tests build their own data and never read this.
--
--   Dino Reyes (discipler@), three Disciples:
--     Diana Cruz (disciple1)     Lesson 1 completed by Dino (5 counted,
--                                one of them Late, and 1 Absent); Lesson
--                                2 in progress: 2 counted, then 3 Absent
--                                in a row. No condition is raised; the
--                                run is shown as a fact.
--     Daniel Bautista (disciple2) Lesson 1 in progress with 6 counted
--                                meetings, ready for Dino to mark it
--                                completed. His first two meetings were
--                                shared with Diana.
--     Ella Navarro (disciple3)   paired, no meeting recorded yet.
--   Grace Lim (discipler2), one Disciple:
--     Hana Torres (disciple5)    Lesson 1 in progress: Present, Excused,
--                                then Late, the last recorded by the
--                                Leader on Grace's behalf, with notes.
--   Felix Ramos (disciple4)      placed, never paired.
--   Lea Santos (leader@)         leads the group; sees all of the above.
--   Dev Admin (admin@)           Coordinator; church-wide.
--
-- Pairing and every meeting go through the real operations, with each
-- account impersonated through request.jwt.claims. Before recording,
-- the D Group rows and assignments are backdated by trusted direct
-- update (plan decision 14) so meetings can carry past dates; the
-- integrity triggers still check every write.
-- Lesson completion goes through complete_lesson() too (ADR-015: the
-- Discipler marks a lesson completed; there is no Leader confirmation).

do $$
declare
  v_church   constant uuid := 'c0000000-0000-4000-8000-000000000001';
  v_leader   constant uuid := 'a0000000-0000-4000-8000-000000000002';
  v_dino     constant uuid := 'a0000000-0000-4000-8000-000000000003';
  v_grace    constant uuid := 'a0000000-0000-4000-8000-000000000007';
  v_lessons  uuid[];
  v_dino_dgm  uuid;
  v_grace_dgm uuid;
  v_diana    uuid;
  v_daniel   uuid;
  v_ella     uuid;
  v_hana     uuid;
begin
  if exists (
    select 1 from public.discipleship_meetings dm
    join public.d_groups g on g.id = dm.d_group_id
    where g.church_id = v_church
  ) then
    return;
  end if;

  select array_agg(l.id order by l.lesson_number) into v_lessons
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where c.church_id = v_church and c.status = 'ACTIVE';

  select m.id into v_diana  from public.church_memberships m where m.user_id = 'a0000000-0000-4000-8000-000000000004';
  select m.id into v_daniel from public.church_memberships m where m.user_id = 'a0000000-0000-4000-8000-000000000005';
  select m.id into v_ella   from public.church_memberships m where m.user_id = 'a0000000-0000-4000-8000-000000000008';
  select m.id into v_hana   from public.church_memberships m where m.user_id = 'a0000000-0000-4000-8000-00000000000a';

  select dgm.id into v_dino_dgm
  from public.d_group_memberships dgm
  join public.church_memberships m on m.id = dgm.church_membership_id
  where m.user_id = v_dino and dgm.ended_at is null;

  select dgm.id into v_grace_dgm
  from public.d_group_memberships dgm
  join public.church_memberships m on m.id = dgm.church_membership_id
  where m.user_id = v_grace and dgm.ended_at is null;

  -- The Leader pairs the Disciples.
  perform set_config('request.jwt.claims', json_build_object('sub', v_leader)::text, true);
  perform public.set_discipler(private.current_disciple_row(v_diana), v_dino_dgm);
  perform public.set_discipler(private.current_disciple_row(v_daniel), v_dino_dgm);
  perform public.set_discipler(private.current_disciple_row(v_ella), v_dino_dgm);
  perform public.set_discipler(private.current_disciple_row(v_hana), v_grace_dgm);

  -- Backdate: Dino and his Disciples 60 days, Grace and Hana 30.
  update public.d_group_memberships
  set started_at = now() - interval '60 days'
  where id in (v_dino_dgm, private.current_disciple_row(v_diana),
               private.current_disciple_row(v_daniel),
               private.current_disciple_row(v_ella));
  update public.discipler_assignments
  set started_at = now() - interval '60 days'
  where discipler_d_group_membership_id = v_dino_dgm and ended_at is null;

  update public.d_group_memberships
  set started_at = now() - interval '30 days'
  where id in (v_grace_dgm, private.current_disciple_row(v_hana));
  update public.discipler_assignments
  set started_at = now() - interval '30 days'
  where discipler_d_group_membership_id = v_grace_dgm and ended_at is null;

  -- Dino records. Lesson 1: two meetings with Diana and Daniel together,
  -- then each continues.
  perform set_config('request.jwt.claims', json_build_object('sub', v_dino)::text, true);
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '56 days',
    jsonb_build_array(
      jsonb_build_object('church_membership_id', v_diana,  'attendance_status', 'PRESENT'),
      jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'PRESENT')),
    'First meeting together. Read the opening passage.');
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '49 days',
    jsonb_build_array(
      jsonb_build_object('church_membership_id', v_diana,  'attendance_status', 'LATE'),
      jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '45 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'ABSENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '42 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '38 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '35 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'PRESENT')));

  -- Dino marks Diana's Lesson 1 completed.
  perform public.complete_lesson(v_diana, v_lessons[1]);

  -- Diana, Lesson 2: two counted meetings, then three recorded absences.
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[2], now() - interval '28 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[2], now() - interval '21 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[2], now() - interval '14 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'ABSENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[2], now() - interval '7 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'ABSENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[2], now() - interval '3 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_diana, 'attendance_status', 'ABSENT')));

  -- Daniel, Lesson 1: four more counted meetings (six in all).
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '40 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '30 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'LATE')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '20 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_dino_dgm, v_lessons[1], now() - interval '10 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_daniel, 'attendance_status', 'PRESENT')),
    'Finished the last section of Lesson 1.');

  -- Grace records for Hana; the Leader records the third on her behalf.
  perform set_config('request.jwt.claims', json_build_object('sub', v_grace)::text, true);
  perform public.record_discipleship_meeting(v_grace_dgm, v_lessons[1], now() - interval '20 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_hana, 'attendance_status', 'PRESENT')));
  perform public.record_discipleship_meeting(v_grace_dgm, v_lessons[1], now() - interval '13 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_hana, 'attendance_status', 'EXCUSED')),
    'Hana was travelling for work.');

  perform set_config('request.jwt.claims', json_build_object('sub', v_leader)::text, true);
  perform public.record_discipleship_meeting(v_grace_dgm, v_lessons[1], now() - interval '6 days',
    jsonb_build_array(jsonb_build_object('church_membership_id', v_hana, 'attendance_status', 'LATE')),
    'Recorded by Lea while Grace was away.');

  perform set_config('request.jwt.claims', '', true);
end
$$;
