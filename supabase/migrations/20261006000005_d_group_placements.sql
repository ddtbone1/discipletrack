-- ============================================================
-- DiscipleTrack - Migration 012: D Group placements (Slice 6.1)
-- ============================================================
--
-- Group membership is separated from responsibility. A person is in a
-- D Group (d_group_placements) and, once set up, holds responsibilities
-- there (d_group_memberships). A placement with no active
-- responsibility is the derived "Needs setup" state.
--
-- Placement is direct (Slice 6 decision 1): the Coordinator (any group
-- in the church) or the group's Leader adds approved, ACTIVE, ungrouped
-- members. Invitation and acceptance are retired: pending invitations
-- are withdrawn here, the table stays as history and the invitation
-- operations are dropped.
--
-- Scope:
--   Schema
--     - d_group_placements, one active placement per person (partial
--       unique index), same church as the group, no overlapping periods
--     - backfill: one placement per person with an active
--       responsibility, from their earliest active row
--     - an active responsibility requires an active placement of the
--       same person in the same group; a placement cannot end while it
--       still holds responsibilities
--   Helpers
--     - is_unplaced() redefined on placements
--     - is_placed_in(), leads_group_of_membership() on placements
--   Controlled operations
--     - create_d_group(), assign_d_group_leader() write placements
--     - list_addable_members(), add_members_to_d_group()
--     - remove_from_d_group() replaces end_d_group_membership()
--     - list_placeable_members() recreated without the invitation flag
--     - get_my_d_group_roster(): a placed person without a
--       responsibility sees their Leader by name only
--   Retired
--     - invite_to_d_group(), withdraw_d_group_invitation(),
--       respond_to_d_group_invitation(), get_my_pending_invitation(),
--       end_d_group_membership()
--   RLS
--     - d_group_placements read policies
--     - d_groups readable by a placed member (group name)
--
-- New error reasons:
--   PT400 members_required / too_many_members
--   PT404 d_group_placement_not_found
--   PT409 d_group_placement_not_active / leader_cannot_be_removed
--
-- Concurrency: every operation that changes a person's placement locks
-- their church_memberships row FOR UPDATE first (in id order when
-- several), as in Migration 006. The partial unique index is the final
-- guarantee: two concurrent adds of one person cannot both commit.
--
-- Migrations 001 to 011 are not modified.
--
-- References:
--   Plan = docs/plans/slice-6-d-group-assignment-discipler-progression.md
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================

create table public.d_group_placements (
  id                    uuid        not null default gen_random_uuid(),
  d_group_id            uuid        not null,
  church_membership_id  uuid        not null,
  started_at            timestamptz not null,
  ended_at              timestamptz,
  placed_by             uuid        not null,
  ended_by              uuid,
  created_at            timestamptz not null default now(),

  constraint d_group_placements_pkey primary key (id),
  constraint d_group_placements_d_group_id_fkey foreign key (d_group_id)
    references public.d_groups (id) on delete no action,
  constraint d_group_placements_membership_fkey
    foreign key (church_membership_id)
    references public.church_memberships (id) on delete no action,
  constraint d_group_placements_placed_by_fkey foreign key (placed_by)
    references public.profiles (id) on delete no action,
  constraint d_group_placements_ended_by_fkey foreign key (ended_by)
    references public.profiles (id) on delete no action,

  constraint d_group_placements_period_check
    check (ended_at is null or ended_at > started_at),
  constraint d_group_placements_ended_by_check
    check ((ended_at is null) = (ended_by is null))
);

comment on table public.d_group_placements is
  'A person''s membership of a D Group, independent of responsibility. Active while ended_at is null; at most one active placement per person. An active placement with no active d_group_memberships row is "Needs setup". Written only by controlled operations.';

-- One active D Group per person, declaratively.
create unique index d_group_placements_one_active_uidx
  on public.d_group_placements (church_membership_id)
  where ended_at is null;

create index d_group_placements_active_group_idx
  on public.d_group_placements (d_group_id)
  where ended_at is null;

alter table public.d_group_placements enable row level security;

revoke all on table public.d_group_placements from anon;
revoke insert, update, delete, truncate on table public.d_group_placements
  from authenticated;


-- Backfill: everyone holding an active responsibility is placed in
-- that group from their earliest active row. Migration 006 already
-- guarantees one group per person.
insert into public.d_group_placements
  (d_group_id, church_membership_id, started_at, placed_by)
select distinct on (dgm.church_membership_id)
  dgm.d_group_id,
  dgm.church_membership_id,
  dgm.started_at,
  dgm.assigned_by
from public.d_group_memberships dgm
where dgm.ended_at is null
order by dgm.church_membership_id, dgm.started_at, dgm.id;


-- Invitations are retired. Withdraw what is still pending so no row is
-- left waiting for an answer nobody can give. An overdue one is marked
-- EXPIRED at the moment it lapsed, as Migration 006 defines.
update public.d_group_invitations i
set status       = 'EXPIRED',
    responded_at = i.expires_at
where i.status = 'PENDING'
  and i.expires_at <= now();

update public.d_group_invitations i
set status       = 'WITHDRAWN',
    responded_at = now()
where i.status = 'PENDING';

comment on table public.d_group_invitations is
  'Historical. Placement by invitation was retired in Migration 012 (Slice 6 decision 1); no operation writes this table any more.';


-- ============================================================
-- 2. INTEGRITY TRIGGERS
-- ============================================================

create function private.check_d_group_placement_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select g.church_id from public.d_groups g where g.id = new.d_group_id)
     is distinct from
     (select m.church_id from public.church_memberships m
      where m.id = new.church_membership_id) then
    raise exception 'd_group_placement_cross_church'
      using errcode = '23514',
            detail = 'The D Group and the church membership belong to different churches.';
  end if;

  if exists (
    select 1
    from public.d_group_placements o
    where o.id <> new.id
      and o.church_membership_id = new.church_membership_id
      and tstzrange(o.started_at, o.ended_at, '[)')
          && tstzrange(new.started_at, new.ended_at, '[)')
  ) then
    raise exception 'd_group_placement_overlap'
      using errcode = '23514',
            detail = 'A person is in at most one D Group at a time.';
  end if;

  if new.ended_at is not null and exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = new.church_membership_id
      and dgm.d_group_id = new.d_group_id
      and dgm.ended_at is null
  ) then
    raise exception 'd_group_placement_has_responsibilities'
      using errcode = '23514',
            detail = 'End the person''s responsibilities in the group before their placement.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_d_group_placement_integrity()
  from public, anon, authenticated;

create constraint trigger d_group_placements_integrity
  after insert or update on public.d_group_placements
  for each row execute function private.check_d_group_placement_integrity();


-- An active responsibility needs an active placement in the same
-- group. Separate from Migration 006's integrity trigger, which Slice
-- 6.2 replaces for the DISCIPLE / DISCIPLER relaxation.
create function private.check_d_group_membership_placement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.ended_at is null and not exists (
    select 1
    from public.d_group_placements p
    where p.church_membership_id = new.church_membership_id
      and p.d_group_id = new.d_group_id
      and p.ended_at is null
  ) then
    raise exception 'd_group_membership_not_placed'
      using errcode = '23514',
            detail = 'An active responsibility requires an active placement in the same D Group.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_d_group_membership_placement()
  from public, anon, authenticated;

create constraint trigger d_group_memberships_placement
  after insert or update on public.d_group_memberships
  for each row execute function private.check_d_group_membership_placement();


-- ============================================================
-- 3. HELPERS
-- ============================================================

-- "Unplaced" now means no active placement. An active responsibility
-- implies an active placement, so this is never looser than before.
create or replace function private.is_unplaced(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.d_group_placements p
    where p.church_membership_id = p_membership_id
      and p.ended_at is null
  );
$$;


-- The caller is placed in the group (with or without a responsibility).
create function private.is_placed_in(p_d_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_placements p
    join public.church_memberships m on m.id = p.church_membership_id
    where p.d_group_id = p_d_group_id
      and p.ended_at is null
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
  );
$$;

revoke execute on function private.is_placed_in(uuid) from public, anon;
grant execute on function private.is_placed_in(uuid) to authenticated, service_role;


-- RBAC section 3, LEADER -> members of own D Group: everyone placed in
-- it, including people who still need setup. The invitee clause of
-- Migration 006 is gone with invitations.
create or replace function private.leads_group_of_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships l
    join public.church_memberships me on me.id = l.church_membership_id
    join public.d_group_placements t on t.d_group_id = l.d_group_id
    where l.responsibility = 'LEADER'
      and l.ended_at is null
      and me.user_id = (select auth.uid())
      and me.status = 'ACTIVE'
      and t.church_membership_id = p_membership_id
      and t.ended_at is null
  );
$$;


-- ============================================================
-- 4. RETIRED OPERATIONS
-- ============================================================

drop function public.invite_to_d_group(uuid, uuid, public.d_group_responsibility);
drop function public.withdraw_d_group_invitation(uuid);
drop function public.respond_to_d_group_invitation(uuid, boolean);
drop function public.get_my_pending_invitation();
drop function public.end_d_group_membership(uuid);
drop function private.expire_overdue_d_group_invitations(uuid);


-- ============================================================
-- 5. CONTROLLED OPERATIONS
-- ============================================================

-- As Migration 006, plus the Leader's placement.
create or replace function public.create_d_group(
  p_name                 text,
  p_description          text,
  p_leader_membership_id uuid
)
returns table (d_group_id uuid, leader_d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_leader public.church_memberships%rowtype;
  v_name   text := trim(coalesce(p_name, ''));
  v_group  uuid;
  v_dgm    uuid;
  v_now    timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_leader
  from public.church_memberships m
  where m.id = p_leader_membership_id
  for update;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_leader.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_name = '' then
    raise exception 'd_group_name_required' using errcode = 'PT400';
  end if;

  if v_leader.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if not private.is_unplaced(v_leader.id) then
    raise exception 'member_already_placed' using errcode = 'PT409';
  end if;

  begin
    insert into public.d_groups (church_id, name, description, created_by)
    values (
      v_leader.church_id,
      v_name,
      nullif(trim(coalesce(p_description, '')), ''),
      v_uid
    )
    returning id into v_group;
  exception
    when unique_violation then
      raise exception 'd_group_name_taken' using errcode = 'PT409';
  end;

  insert into public.d_group_placements
    (d_group_id, church_membership_id, started_at, placed_by)
  values (v_group, v_leader.id, v_now, v_uid);

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group, v_leader.id, 'LEADER', v_now, v_uid)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_leader.church_id,
    v_uid,
    'D_GROUP_CREATED',
    'd_groups',
    v_group,
    jsonb_build_object(
      'name', v_name,
      'leader_church_membership_id', v_leader.id,
      'leader_d_group_membership_id', v_dgm
    )
  );

  return query select v_group, v_dgm;
end;
$$;


-- The new Leader is unplaced, or placed in this group holding nothing
-- but a DISCIPLER row (or nothing at all: Needs setup). DISCIPLE
-- excludes LEADER (BR-015). The replaced Leader keeps any DISCIPLER row
-- they hold here; otherwise they leave the group.
create or replace function public.assign_d_group_leader(
  p_d_group_id    uuid,
  p_membership_id uuid
)
returns table (d_group_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_target public.church_memberships%rowtype;
  v_old    public.d_group_memberships%rowtype;
  v_dgm    uuid;
  v_now    timestamptz := now();
  v_old_left boolean := false;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for update;

  if not found then
    raise exception 'd_group_not_found' using errcode = 'PT404';
  end if;

  if not private.is_church_coordinator(v_group.church_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select * into v_old
  from public.d_group_memberships dgm
  where dgm.d_group_id = v_group.id
    and dgm.responsibility = 'LEADER'
    and dgm.ended_at is null;

  -- Lock both people in id order so two replacements cannot deadlock.
  perform 1
  from public.church_memberships m
  where m.id in (p_membership_id, v_old.church_membership_id)
    and m.church_id = v_group.church_id
  order by m.id
  for update;

  select * into v_target
  from public.church_memberships m
  where m.id = p_membership_id
    and m.church_id = v_group.church_id;

  if not found then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  if v_target.status <> 'ACTIVE' then
    raise exception 'member_not_active' using errcode = 'PT409';
  end if;

  if v_old.church_membership_id = v_target.id then
    raise exception 'already_leader' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from public.d_group_placements p
    where p.church_membership_id = v_target.id
      and p.ended_at is null
      and p.d_group_id <> v_group.id
  ) or exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_target.id
      and dgm.ended_at is null
      and dgm.responsibility <> 'DISCIPLER'
  ) then
    raise exception 'leader_not_eligible' using errcode = 'PT409';
  end if;

  if v_old.id is not null then
    update public.d_group_memberships dgm
    set ended_at = v_now
    where dgm.id = v_old.id;

    if not exists (
      select 1
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_old.church_membership_id
        and dgm.d_group_id = v_group.id
        and dgm.ended_at is null
    ) then
      update public.d_group_placements p
      set ended_at = v_now,
          ended_by = v_uid
      where p.church_membership_id = v_old.church_membership_id
        and p.d_group_id = v_group.id
        and p.ended_at is null;
      v_old_left := true;
    end if;
  end if;

  if private.is_unplaced(v_target.id) then
    insert into public.d_group_placements
      (d_group_id, church_membership_id, started_at, placed_by)
    values (v_group.id, v_target.id, v_now, v_uid);
  end if;

  insert into public.d_group_memberships
    (d_group_id, church_membership_id, responsibility, started_at, assigned_by)
  values (v_group.id, v_target.id, 'LEADER', v_now, v_uid)
  returning id into v_dgm;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_group.church_id,
    v_uid,
    'D_GROUP_LEADER_ASSIGNED',
    'd_groups',
    v_group.id,
    jsonb_build_object(
      'from_church_membership_id', v_old.church_membership_id,
      'from_d_group_membership_id', v_old.id,
      'from_left_group', v_old_left,
      'to_church_membership_id', v_target.id,
      'to_d_group_membership_id', v_dgm
    )
  );

  return query select v_dgm;
end;
$$;

comment on function public.assign_d_group_leader(uuid, uuid) is
  'Coordinator only. Replaces (or sets) the active LEADER of a D Group in one transaction. The new Leader is unplaced, or in this group with no responsibility other than DISCIPLER. The previous Leader leaves the group unless they are also a Discipler there. Audited as D_GROUP_LEADER_ASSIGNED.';


-- Read-only. The people the Coordinator or the group's Leader may add:
-- ACTIVE members of the group's church with no active placement. Names
-- only, never phone numbers.
create function public.list_addable_members(p_d_group_id uuid)
returns table (
  church_membership_id uuid,
  full_name            text,
  joined_at            timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_church uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  -- Authority first, so an unknown group and someone else's group are
  -- refused alike and reveal nothing.
  if not private.can_manage_d_group_members(p_d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = p_d_group_id;

  return query
    select m.id, p.full_name, m.joined_at
    from public.church_memberships m
    join public.profiles p on p.id = m.user_id
    where m.church_id = v_church
      and m.status = 'ACTIVE'
      and not exists (
        select 1
        from public.d_group_placements pl
        where pl.church_membership_id = m.id
          and pl.ended_at is null
      )
    order by lower(p.full_name), m.id;
end;
$$;

comment on function public.list_addable_members(uuid) is
  'Coordinator or the group''s Leader. ACTIVE members of the church who are in no D Group, by name. No phone numbers.';


-- Slice 6 decision 1. All or nothing: if any chosen person was placed
-- meanwhile, nobody is added and the reason names the conflict.
create function public.add_members_to_d_group(
  p_d_group_id     uuid,
  p_membership_ids uuid[]
)
returns table (d_group_placement_id uuid, church_membership_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_group  public.d_groups%rowtype;
  v_ids    uuid[];
  v_locked integer;
  v_bad    uuid;
  v_now    timestamptz := now();
  v_id     uuid;
  v_pid    uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if not private.can_manage_d_group_members(p_d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  select * into v_group
  from public.d_groups g
  where g.id = p_d_group_id
  for share;

  if v_group.status <> 'ACTIVE' then
    raise exception 'd_group_not_active' using errcode = 'PT409';
  end if;

  select coalesce(array_agg(distinct x order by x), '{}')
  into v_ids
  from unnest(coalesce(p_membership_ids, '{}')) as x
  where x is not null;

  if cardinality(v_ids) = 0 then
    raise exception 'members_required' using errcode = 'PT400';
  end if;

  if cardinality(v_ids) > 100 then
    raise exception 'too_many_members' using errcode = 'PT400';
  end if;

  -- Lock everyone in id order, so concurrent adds serialise without
  -- deadlocking. Someone in another church counts as not found.
  with locked as (
    select m.id
    from public.church_memberships m
    where m.id = any(v_ids)
      and m.church_id = v_group.church_id
    order by m.id
    for update
  )
  select count(*) into v_locked from locked;

  if v_locked <> cardinality(v_ids) then
    raise exception 'membership_not_found' using errcode = 'PT404';
  end if;

  select m.id into v_bad
  from public.church_memberships m
  where m.id = any(v_ids)
    and m.status <> 'ACTIVE'
  order by m.id
  limit 1;

  if v_bad is not null then
    raise exception 'member_not_active' using errcode = 'PT409',
      detail = v_bad::text;
  end if;

  select p.church_membership_id into v_bad
  from public.d_group_placements p
  where p.church_membership_id = any(v_ids)
    and p.ended_at is null
  order by p.church_membership_id
  limit 1;

  if v_bad is not null then
    raise exception 'member_already_placed' using errcode = 'PT409',
      detail = v_bad::text;
  end if;

  foreach v_id in array v_ids loop
    begin
      insert into public.d_group_placements
        (d_group_id, church_membership_id, started_at, placed_by)
      values (v_group.id, v_id, v_now, v_uid)
      returning id into v_pid;
    exception
      when unique_violation then
        raise exception 'member_already_placed' using errcode = 'PT409',
          detail = v_id::text;
    end;

    insert into public.audit_events
      (church_id, actor_user_id, action, entity_type, entity_id, metadata)
    values (
      v_group.church_id,
      v_uid,
      'D_GROUP_MEMBER_PLACED',
      'd_group_placements',
      v_pid,
      jsonb_build_object(
        'd_group_id', v_group.id,
        'church_membership_id', v_id
      )
    );

    d_group_placement_id := v_pid;
    church_membership_id := v_id;
    return next;
  end loop;
end;
$$;

comment on function public.add_members_to_d_group(uuid, uuid[]) is
  'Coordinator or the group''s Leader. Places ACTIVE, ungrouped members of the church in the group, all or nothing (at most 100 per call). They hold no responsibility until set up. Audited as D_GROUP_MEMBER_PLACED, one event per person.';


-- Removal takes the person out of the group: every active assignment
-- on either side of their rows, every responsibility, then the
-- placement. The Leader is changed by replacement, never removed.
-- The person's membership need not be ACTIVE.
create function public.remove_from_d_group(p_d_group_placement_id uuid)
returns table (d_group_placement_id uuid, ended_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_pl      public.d_group_placements%rowtype;
  v_church  uuid;
  v_roles   public.d_group_responsibility[];
  v_ended   uuid[];
  v_now     timestamptz := now();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select * into v_pl
  from public.d_group_placements p
  where p.id = p_d_group_placement_id;

  -- Unknown and not-yours are refused alike.
  if not found or not private.can_manage_d_group_members(v_pl.d_group_id) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  perform 1
  from public.church_memberships m
  where m.id = v_pl.church_membership_id
  for update;

  select * into v_pl
  from public.d_group_placements p
  where p.id = p_d_group_placement_id
  for update;

  if v_pl.ended_at is not null then
    raise exception 'd_group_placement_not_active' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_pl.church_membership_id
      and dgm.d_group_id = v_pl.d_group_id
      and dgm.responsibility = 'LEADER'
      and dgm.ended_at is null
  ) then
    raise exception 'leader_cannot_be_removed' using errcode = 'PT409';
  end if;

  -- MONITORING HOOK: resolve the ACTIVE condition of each assignment
  -- ended here when Slice 9 adds one.
  with ended as (
    update public.discipler_assignments a
    set ended_at = v_now
    where a.ended_at is null
      and exists (
        select 1
        from public.d_group_memberships dgm
        where dgm.church_membership_id = v_pl.church_membership_id
          and dgm.d_group_id = v_pl.d_group_id
          and dgm.ended_at is null
          and dgm.id in (a.discipler_d_group_membership_id,
                         a.disciple_d_group_membership_id)
      )
    returning a.id
  )
  select coalesce(array_agg(ended.id), '{}') into v_ended from ended;

  with ended as (
    update public.d_group_memberships dgm
    set ended_at = v_now
    where dgm.church_membership_id = v_pl.church_membership_id
      and dgm.d_group_id = v_pl.d_group_id
      and dgm.ended_at is null
    returning dgm.responsibility
  )
  select coalesce(array_agg(ended.responsibility order by ended.responsibility), '{}')
  into v_roles from ended;

  update public.d_group_placements p
  set ended_at = v_now,
      ended_by = v_uid
  where p.id = v_pl.id;

  select g.church_id into v_church
  from public.d_groups g
  where g.id = v_pl.d_group_id;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_church,
    v_uid,
    'D_GROUP_MEMBER_REMOVED',
    'd_group_placements',
    v_pl.id,
    jsonb_build_object(
      'd_group_id', v_pl.d_group_id,
      'church_membership_id', v_pl.church_membership_id,
      'ended_responsibilities', to_jsonb(v_roles),
      'ended_discipler_assignment_ids', to_jsonb(v_ended)
    )
  );

  return query select v_pl.id, v_now;
end;
$$;

comment on function public.remove_from_d_group(uuid) is
  'Coordinator or the group''s Leader. Ends a placement with every responsibility the person holds in the group and every discipler assignment on either side. The Leader is refused. Audited as D_GROUP_MEMBER_REMOVED.';


-- Recreated without has_pending_invitation, and on placements: a
-- placed person with no responsibility reports their group with an
-- empty responsibility list. Used for choosing a Leader.
drop function public.list_placeable_members(uuid, uuid);

create function public.list_placeable_members(
  p_d_group_id uuid default null,
  p_church_id  uuid default null
)
returns table (
  church_membership_id     uuid,
  full_name                text,
  current_d_group_id       uuid,
  current_d_group_name     text,
  current_responsibilities public.d_group_responsibility[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid           uuid := (select auth.uid());
  v_church        uuid;
  v_unplaced_only boolean;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if p_d_group_id is not null then
    if not private.can_manage_d_group_members(p_d_group_id) then
      raise exception 'not_authorized' using errcode = 'PT403';
    end if;

    select g.church_id into v_church
    from public.d_groups g
    where g.id = p_d_group_id;
  else
    v_church := p_church_id;
  end if;

  if v_church is null or (p_d_group_id is null and not private.is_church_coordinator(v_church)) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  v_unplaced_only := not private.is_church_coordinator(v_church);

  return query
    select
      m.id,
      p.full_name,
      pl.d_group_id,
      g.name,
      case
        when pl.id is null then null
        else coalesce((
          select array_agg(dgm.responsibility order by dgm.responsibility)
          from public.d_group_memberships dgm
          where dgm.church_membership_id = m.id
            and dgm.d_group_id = pl.d_group_id
            and dgm.ended_at is null
        ), '{}')
      end
    from public.church_memberships m
    join public.profiles p on p.id = m.user_id
    left join public.d_group_placements pl
      on pl.church_membership_id = m.id and pl.ended_at is null
    left join public.d_groups g on g.id = pl.d_group_id
    where m.church_id = v_church
      and m.status = 'ACTIVE'
      and (not v_unplaced_only or pl.id is null)
    order by lower(p.full_name), m.id;
end;
$$;

comment on function public.list_placeable_members(uuid, uuid) is
  'Coordinator (or the group''s Leader, unplaced members only). ACTIVE members with their current D Group and responsibilities; an empty list means placed but not set up. No phone numbers.';


-- As Migration 006, with the caller's group taken from their placement.
-- A placed person with no responsibility (Needs setup) sees only their
-- Leader, by name: they have no group role yet, so no roster and no
-- phone number (Plan, defaults).
create or replace function public.get_my_d_group_roster()
returns table (
  d_group_id            uuid,
  d_group_name          text,
  d_group_membership_id uuid,
  church_membership_id  uuid,
  full_name             text,
  responsibility        public.d_group_responsibility,
  phone                 text,
  is_me                 boolean,
  is_my_leader          boolean,
  is_my_discipler       boolean,
  is_my_disciple        boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_me    uuid;
  v_group uuid;
  v_set_up boolean;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  select pl.church_membership_id, pl.d_group_id into v_me, v_group
  from public.d_group_placements pl
  join public.church_memberships m on m.id = pl.church_membership_id
  where m.user_id = v_uid
    and m.status = 'ACTIVE'
    and pl.ended_at is null
  limit 1;

  if v_group is null then
    return;
  end if;

  v_set_up := exists (
    select 1
    from public.d_group_memberships dgm
    where dgm.church_membership_id = v_me
      and dgm.d_group_id = v_group
      and dgm.ended_at is null
  );

  return query
    with mine as (
      select dgm.id, dgm.responsibility
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_me
        and dgm.d_group_id = v_group
        and dgm.ended_at is null
    ),
    my_discipler as (
      select dr.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
      where a.ended_at is null
        and a.disciple_d_group_membership_id in (select mine.id from mine)
    ),
    my_disciples as (
      select dd.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
      where a.ended_at is null
        and dd.ended_at is null
        and a.discipler_d_group_membership_id in (select mine.id from mine)
    )
    select
      g.id,
      g.name,
      dgm.id,
      dgm.church_membership_id,
      p.full_name,
      dgm.responsibility,
      case
        when dgm.church_membership_id = v_me then p.phone
        when (dgm.responsibility = 'LEADER'
              and exists (select 1 from mine where mine.responsibility <> 'LEADER'))
          or dgm.church_membership_id in (select md.church_membership_id from my_discipler md)
          or dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds)
          then p.phone
        else null
      end,
      dgm.church_membership_id = v_me,
      dgm.responsibility = 'LEADER' and dgm.church_membership_id <> v_me,
      dgm.church_membership_id in (select md.church_membership_id from my_discipler md),
      dgm.church_membership_id in (select mds.church_membership_id from my_disciples mds)
    from public.d_group_memberships dgm
    join public.d_groups g on g.id = dgm.d_group_id
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.profiles p on p.id = m.user_id
    where dgm.d_group_id = v_group
      and dgm.ended_at is null
      and (v_set_up or dgm.responsibility = 'LEADER')
    order by
      case dgm.responsibility
        when 'LEADER' then 0
        when 'DISCIPLER' then 1
        else 2
      end,
      lower(p.full_name);
end;
$$;

comment on function public.get_my_d_group_roster() is
  'The caller''s D Group roster by name, with phone numbers only for their own Leader, own Discipler and, for a Discipler, their assigned Disciples. A caller who still needs setup gets only their Leader''s row, without a phone number.';


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.list_addable_members(uuid)',
    'public.add_members_to_d_group(uuid, uuid[])',
    'public.remove_from_d_group(uuid)',
    'public.list_placeable_members(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================

-- Coordinator church-wide and the Leader their own group, history
-- included; a person their own placements.
create policy d_group_placements_select_manager
  on public.d_group_placements
  for select
  to authenticated
  using (private.can_manage_d_group_members(d_group_id));

create policy d_group_placements_select_own
  on public.d_group_placements
  for select
  to authenticated
  using (private.is_my_membership(church_membership_id));

-- A placed member who still needs setup can read their group's row
-- (its name). Members with a responsibility already can.
create policy d_groups_select_placed
  on public.d_groups
  for select
  to authenticated
  using (private.is_placed_in(id));
