-- ============================================================
-- DiscipleTrack - Migration 027: a Discipler's own complete lessons
-- ============================================================
--
-- Slice 8 Phase 4 (ADR-024, amending ADR-023 decisions 2 and 3).
-- Replaces private.can_read_lesson_tier() once more. Only the
-- own-context branch changes:
--
--   reader, in the context of               opens
--   own context, holding an active          all ten lessons, both tiers
--     DISCIPLER responsibility (every
--     Leader, ADR-020)
--   own context, anyone else                Disciple tier of own reached lessons
--   a currently assigned Discipler          all ten lessons, both tiers
--   the Leader of the Disciple's current    Disciple tier of that Disciple's
--     group (Disciple assigned elsewhere)     reached lessons, never answers
--   the Coordinator, any context            all ten lessons, both tiers
--   anyone else, or a non-ACTIVE church     nothing
--
-- A Discipler prepares and teaches from the Discipler's Copy, from
-- appointment, before any Disciple is paired (ADR-024 decision 1). The
-- grant ends with the DISCIPLER row: removal, transfer or the end of the
-- responsibility closes it at once.
--
-- A member who is also a Disciple (both responsibilities) may now read
-- every lesson in their own context. Their journey is unchanged:
-- progression is recorded only by their Discipler (ADR-015), and My
-- Journey presents their own reached lessons, as it already does for the
-- Coordinator (ADR-023 decision 10).
--
-- get_lesson_content(), list_lesson_access(), get_my_readable_content()
-- and check_lesson_answers() all ask this function, so they follow
-- without change. No client-callable function is added, so the
-- church-status registry sweep is unchanged; the church status gate
-- stays first.
--
-- References:
--   ADR-024, ADR-023, RBAC_RLS_MATRIX.md sections 2 and 5,
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

  -- The Coordinator: every lesson, both tiers, any context (ADR-023
  -- decision 9).
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

  if private.is_my_membership(v_for) then
    -- A Discipler, every Leader included: the whole book, both tiers
    -- (ADR-024 decision 1).
    if exists (
      select 1
      from public.d_group_memberships dgm
      where dgm.church_membership_id = v_for
        and dgm.responsibility = 'DISCIPLER'
        and dgm.ended_at is null
    ) then
      return true;
    end if;
    -- Anyone else: their own journey, Disciple tier, reached lessons.
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
  'Whether the caller may read one tier of a lesson in a person''s context (own when null). ADR-024 and ADR-023: own context, a Discipler (every Leader) all ten lessons, both tiers, anyone else their own journey; a currently assigned Disciple all ten lessons, both tiers; another Disciple of the led group the Disciple tier of reached lessons; the Coordinator everything; nothing while the church is not ACTIVE.';
