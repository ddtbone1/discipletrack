-- ============================================================
-- DiscipleTrack - Migration 026: curriculum access follows the
--                                relationship
-- ============================================================
--
-- Slice 8 (ADR-023, superseding ADR-019 decision 16). Replaces
-- private.can_read_lesson_tier(), the one rule every lesson read uses
-- (get_lesson_content(), list_lesson_access(),
-- get_my_readable_content(), check_lesson_answers()):
--
--   reader, in the context of               opens
--   any reader, own context                 Disciple tier of own reached lessons
--   a currently assigned Discipler          all ten lessons, both tiers
--   the Leader of the Disciple's current    Disciple tier of that Disciple's
--     group (Disciple assigned elsewhere)     reached lessons, never answers
--   the Coordinator, any context            all ten lessons, both tiers
--   anyone else, or a non-ACTIVE church     nothing
--
-- A Discipler or Leader therefore opens only their own journey in their
-- own context (ADR-023 decision 2). The Coordinator keeps full access in
-- every context, their own included (decision 9). Reading writes
-- nothing and never affects progression (decision 11): this is a pure
-- read of progress.
--
-- private.is_discipler_in_church() (Migration 019), used only by the
-- rule it replaces, is dropped.
--
-- get_my_readable_content() needs no change: it already asks this
-- function for the reader's own context, each currently assigned
-- Disciple and each active Disciple of a group the reader leads, so the
-- device copy follows the new rule. The open tiers of one context come
-- from list_lesson_access(p_for_membership_id).
--
-- References:
--   ADR-023, RBAC_RLS_MATRIX.md sections 2 and 5,
--   DATABASE_CONSTRAINTS.md section 11 (Reached Lessons)
-- ============================================================

create or replace function private.can_read_lesson_tier(
  p_lesson_id         uuid,
  p_tier              public.content_tier,
  p_for_membership_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_church uuid;
  v_for    uuid := p_for_membership_id;
begin
  select c.church_id into v_church
  from public.curriculum_lessons l
  join public.curricula c on c.id = l.curriculum_id
  where l.id = p_lesson_id;

  if v_church is null or not private.church_is_active(v_church) then
    return false;
  end if;

  -- The Coordinator: every lesson, both tiers, any context (decision 9).
  if private.is_church_coordinator(v_church) then
    return true;
  end if;

  if v_for is null then
    select m.id into v_for
    from public.church_memberships m
    where m.church_id = v_church
      and m.user_id = (select auth.uid())
      and m.status = 'ACTIVE';
    if v_for is null then
      return false;
    end if;
  end if;

  -- The context person must belong to the lesson's church.
  if not exists (
    select 1
    from public.church_memberships m
    where m.id = v_for and m.church_id = v_church
  ) then
    return false;
  end if;

  -- Own context: own journey only, Disciple tier, reached lessons.
  if private.is_my_membership(v_for) then
    return p_tier = 'DISCIPLE' and private.has_reached_lesson(v_for, p_lesson_id);
  end if;

  -- A currently assigned Disciple: all ten lessons, both tiers.
  if private.is_assigned_discipler_of(v_for) then
    return true;
  end if;

  -- Another active Disciple of the group the reader leads: what that
  -- Disciple sees, never answers.
  if p_tier = 'DISCIPLE'
     and private.leads_current_group_of_disciple(v_for)
     and private.has_reached_lesson(v_for, p_lesson_id) then
    return true;
  end if;

  return false;
end;
$$;

comment on function private.can_read_lesson_tier(uuid, public.content_tier, uuid) is
  'Whether the caller may read one tier of a lesson in a person''s context (own when null). ADR-023: own context own journey only; a currently assigned Disciple all ten lessons, both tiers; another Disciple of the led group the Disciple tier of reached lessons; the Coordinator everything; nothing while the church is not ACTIVE.';

drop function private.is_discipler_in_church(uuid);
