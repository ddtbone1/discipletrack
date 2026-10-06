-- ============================================================
-- DiscipleTrack - Migration 017: Curriculum content (Slice 7.1)
-- ============================================================
--
-- Lesson content structures, publishing and progression-gated reads,
-- under ADR-010 as amended by ADR-019.
--
--   curriculum_publications  one row per publication of a curriculum;
--                            METADATA or FULL; FULL requires a recorded
--                            licence reference (ADR-019 decision 3)
--   lesson_content_blocks    ordered blocks of a lesson, each in one
--                            tier (DISCIPLE or DISCIPLER)
--   lesson_block_answers     answers to fill-in blocks, stored apart so
--                            the database withholds them by policy
--                            (ADR-019 decision 5); always Discipler tier
--
-- Rows are never edited or deleted. Republishing supersedes the
-- current publication and inserts a new one; history is kept (ADR-006).
-- A METADATA publication may hold only identifying blocks (ADR-019
-- decision 2): theme, topic list, section heading, scripture
-- references, module heading. The database refuses anything else, so
-- no substantive wording can be published by mistake.
--
-- Clients hold no grant on these tables and RLS has no client policy:
-- every read goes through the operations in section 4, which apply
-- ADR-019 decision 6 in one place.
--
-- Error reasons:
--   PT400 invalid_curriculum_definition
--   PT401 authentication_required
--   PT403 not_authorized
--
-- Migrations 001 to 016 are not modified.
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================

create type public.curriculum_content_level as enum ('METADATA', 'FULL');

create type public.content_tier as enum ('DISCIPLE', 'DISCIPLER');

create type public.lesson_block_type as enum (
  -- identifying metadata, allowed in a METADATA publication
  'LESSON_THEME',
  'TOPIC_LIST',
  'SECTION_HEADING',
  'SCRIPTURE_REFERENCES',
  'MODULE_HEADING',
  -- substantive content, FULL publications only
  'KEY_OBJECTIVE',
  'BANNER',
  'PARAGRAPH',
  'FILL_IN',
  'DISCUSSION_PROMPTS',
  'SCENARIO',
  'VERSE_WRITING',
  'ASSIGNMENTS',
  'DISCIPLER_NOTE'
);

create table public.curriculum_publications (
  id                 uuid                            not null default gen_random_uuid(),
  curriculum_id      uuid                            not null,
  version            integer                         not null,
  content_level      public.curriculum_content_level not null,
  licence_reference  text,
  published_by       uuid                            not null,
  published_at       timestamptz                     not null default now(),
  superseded_at      timestamptz,
  created_at         timestamptz                     not null default now(),

  constraint curriculum_publications_pkey primary key (id),
  constraint curriculum_publications_curriculum_fkey foreign key (curriculum_id)
    references public.curricula (id) on delete no action,
  constraint curriculum_publications_published_by_fkey foreign key (published_by)
    references public.profiles (id) on delete no action,
  constraint curriculum_publications_version_key unique (curriculum_id, version),
  constraint curriculum_publications_version_check check (version > 0),

  -- ADR-019 decision 3: full content only with recorded permission.
  constraint curriculum_publications_licence_check check (
    content_level = 'METADATA'
    or length(trim(coalesce(licence_reference, ''))) > 0
  ),
  constraint curriculum_publications_superseded_check
    check (superseded_at is null or superseded_at >= published_at)
);

comment on table public.curriculum_publications is
  'Publications of a curriculum''s lesson content (ADR-010, ADR-019). At most one current (superseded_at null) per curriculum. FULL requires licence_reference. Written only by publish_curriculum(); never edited except to set superseded_at; never deleted.';

create unique index curriculum_publications_one_current_uidx
  on public.curriculum_publications (curriculum_id)
  where superseded_at is null;


create table public.lesson_content_blocks (
  id              uuid                     not null default gen_random_uuid(),
  publication_id  uuid                     not null,
  lesson_id       uuid                     not null,
  ordinal         integer                  not null,
  section_label   text,
  block_type      public.lesson_block_type not null,
  tier            public.content_tier      not null,
  body            jsonb                    not null,
  created_at      timestamptz              not null default now(),

  constraint lesson_content_blocks_pkey primary key (id),
  constraint lesson_content_blocks_publication_fkey foreign key (publication_id)
    references public.curriculum_publications (id) on delete no action,
  constraint lesson_content_blocks_lesson_fkey foreign key (lesson_id)
    references public.curriculum_lessons (id) on delete no action,
  constraint lesson_content_blocks_ordinal_key
    unique (publication_id, lesson_id, ordinal),
  constraint lesson_content_blocks_ordinal_check check (ordinal > 0),
  constraint lesson_content_blocks_body_check
    check (jsonb_typeof(body) = 'object'),
  constraint lesson_content_blocks_section_check
    check (section_label is null or length(trim(section_label)) > 0)
);

comment on table public.lesson_content_blocks is
  'Ordered lesson content blocks of one publication, each in exactly one tier (ADR-019 decision 5). Content belongs to a lesson, never to a person; progress and meetings never key to it (ADR-010 decisions 5 and 6).';

create index lesson_content_blocks_lesson_idx
  on public.lesson_content_blocks (lesson_id, publication_id);


create table public.lesson_block_answers (
  id          uuid        not null default gen_random_uuid(),
  block_id    uuid        not null,
  answers     jsonb       not null,
  created_at  timestamptz not null default now(),

  constraint lesson_block_answers_pkey primary key (id),
  constraint lesson_block_answers_block_fkey foreign key (block_id)
    references public.lesson_content_blocks (id) on delete no action,
  constraint lesson_block_answers_block_key unique (block_id),
  -- One entry per blank; each entry is the list of accepted answers.
  constraint lesson_block_answers_shape_check
    check (jsonb_typeof(answers) = 'array')
);

comment on table public.lesson_block_answers is
  'Answers to FILL_IN blocks, kept apart from the blocks so the database can withhold them (ADR-019 decision 5). Discipler tier only. FULL publications only.';


alter table public.curriculum_publications enable row level security;
alter table public.lesson_content_blocks   enable row level security;
alter table public.lesson_block_answers    enable row level security;

revoke all on table
  public.curriculum_publications,
  public.lesson_content_blocks,
  public.lesson_block_answers
from anon, authenticated;


-- ============================================================
-- 2. INTEGRITY TRIGGERS
-- ============================================================

-- A block belongs to a lesson of its publication's curriculum, has the
-- body its type needs, sits in the tier its type allows, and appears
-- in a FULL publication unless it is identifying metadata.
create function private.check_lesson_content_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pub public.curriculum_publications%rowtype;
  v_required text;
begin
  select * into v_pub
  from public.curriculum_publications p
  where p.id = new.publication_id;

  if not exists (
    select 1
    from public.curriculum_lessons l
    where l.id = new.lesson_id
      and l.curriculum_id = v_pub.curriculum_id
  ) then
    raise exception 'content_block_lesson_mismatch'
      using errcode = '23514',
            detail = 'The lesson does not belong to the publication''s curriculum.';
  end if;

  if v_pub.content_level = 'METADATA' and new.block_type not in (
    'LESSON_THEME', 'TOPIC_LIST', 'SECTION_HEADING',
    'SCRIPTURE_REFERENCES', 'MODULE_HEADING'
  ) then
    raise exception 'content_block_not_metadata'
      using errcode = '23514',
            detail = 'A METADATA publication holds identifying blocks only (ADR-019 decision 2).';
  end if;

  if new.block_type in ('MODULE_HEADING', 'DISCIPLER_NOTE')
     and new.tier <> 'DISCIPLER' then
    raise exception 'content_block_tier_invalid'
      using errcode = '23514',
            detail = 'Training modules and Discipler notes are Discipler tier.';
  end if;

  v_required := case new.block_type
    when 'TOPIC_LIST'           then 'items'
    when 'DISCUSSION_PROMPTS'   then 'items'
    when 'ASSIGNMENTS'          then 'items'
    when 'SCRIPTURE_REFERENCES' then 'refs'
    when 'VERSE_WRITING'        then 'reference'
    when 'MODULE_HEADING'       then 'title'
    when 'SECTION_HEADING'      then null   -- a section may be known by its label only
    else 'text'
  end;

  if v_required is not null and not (new.body ? v_required) then
    raise exception 'content_block_body_invalid'
      using errcode = '23514',
            detail = format('A %s block needs a "%s" key.', new.block_type, v_required);
  end if;

  if new.block_type in ('TOPIC_LIST', 'DISCUSSION_PROMPTS', 'ASSIGNMENTS', 'SCRIPTURE_REFERENCES')
     and jsonb_typeof(new.body -> v_required) <> 'array' then
    raise exception 'content_block_body_invalid'
      using errcode = '23514',
            detail = format('"%s" of a %s block is a list.', v_required, new.block_type);
  end if;

  return null;
end;
$$;

revoke execute on function private.check_lesson_content_block()
  from public, anon, authenticated;

create constraint trigger lesson_content_blocks_integrity
  after insert on public.lesson_content_blocks
  for each row execute function private.check_lesson_content_block();


-- Answers only for FILL_IN blocks of FULL publications.
create function private.check_lesson_block_answers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.lesson_content_blocks b
    join public.curriculum_publications p on p.id = b.publication_id
    where b.id = new.block_id
      and b.block_type = 'FILL_IN'
      and p.content_level = 'FULL'
  ) then
    raise exception 'answers_block_invalid'
      using errcode = '23514',
            detail = 'Answers belong to FILL_IN blocks of a FULL publication.';
  end if;

  return null;
end;
$$;

revoke execute on function private.check_lesson_block_answers()
  from public, anon, authenticated;

create constraint trigger lesson_block_answers_integrity
  after insert on public.lesson_block_answers
  for each row execute function private.check_lesson_block_answers();


-- Published rows are history: blocks and answers are never edited; a
-- publication changes only once, to record when it was superseded.
-- Deletion is already impossible for clients (no grant), as for every
-- other history table.
create function private.refuse_content_rewrite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name <> 'curriculum_publications' then
    raise exception 'content_history_immutable'
      using errcode = '23514',
            detail = 'Published content is never edited; republish instead.';
  end if;

  if old.superseded_at is null
     and new.superseded_at is not null
     and (new.id, new.curriculum_id, new.version, new.content_level,
          new.licence_reference, new.published_by, new.published_at)
         is not distinct from
         (old.id, old.curriculum_id, old.version, old.content_level,
          old.licence_reference, old.published_by, old.published_at) then
    return new;
  end if;

  raise exception 'content_history_immutable'
    using errcode = '23514',
          detail = 'Published content is never edited; republish instead.';
end;
$$;

revoke execute on function private.refuse_content_rewrite()
  from public, anon, authenticated;

create trigger curriculum_publications_immutable
  before update on public.curriculum_publications
  for each row execute function private.refuse_content_rewrite();

create trigger lesson_content_blocks_immutable
  before update on public.lesson_content_blocks
  for each row execute function private.refuse_content_rewrite();

create trigger lesson_block_answers_immutable
  before update on public.lesson_block_answers
  for each row execute function private.refuse_content_rewrite();


-- ============================================================
-- 3. ACCESS HELPERS (ADR-019 decision 6)
-- ============================================================

-- "Reached", derived and never stored: every lesson the person has
-- COMPLETED, plus their current lesson only while they hold an active
-- DISCIPLE responsibility. The default Lesson 1 that eligible_lesson()
-- resolves for anyone grants nothing on its own ("no journey, no
-- curriculum").
create function private.has_reached_lesson(
  p_membership_id uuid,
  p_lesson_id     uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1
           from public.disciple_lesson_progress p
           where p.church_membership_id = p_membership_id
             and p.lesson_id = p_lesson_id
             and p.status = 'COMPLETED'
         )
      or (
           private.current_disciple_row(p_membership_id) is not null
           and private.eligible_lesson(p_membership_id) = p_lesson_id
         );
$$;


-- Whether the caller may read one tier of a lesson, in the context of
-- a person (p_for_membership_id), or of themselves when it is null.
--
--   Coordinator of the lesson's church   both tiers, any lesson
--   the person themselves                Disciple tier, reached lessons
--   their current assigned Discipler     both tiers, reached lessons
--   Leader of their current group        Disciple tier, reached lessons,
--     (the person an active Disciple)    never the Discipler tier
--   anyone else                          nothing
create function private.can_read_lesson_tier(
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

  if v_church is null then
    return false;
  end if;

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

  if not private.has_reached_lesson(v_for, p_lesson_id) then
    return false;
  end if;

  if private.is_my_membership(v_for) then
    return p_tier = 'DISCIPLE';
  end if;

  if private.is_assigned_discipler_of(v_for) then
    return true;
  end if;

  if p_tier = 'DISCIPLE' and private.leads_current_group_of_disciple(v_for) then
    return true;
  end if;

  return false;
end;
$$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'private.has_reached_lesson(uuid, uuid)',
    'private.can_read_lesson_tier(uuid, public.content_tier, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;


-- ============================================================
-- 4. OPERATIONS
-- ============================================================

-- Trusted publishing (ADR-010 decision 2, ADR-019 decision 4):
-- service_role only. Validates the definition against the church's
-- ACTIVE curriculum (every lesson, in order), supersedes the current
-- publication, inserts the blocks (and answers for FULL), sets each
-- lesson's identifying title, and audits.
--
-- Definition shape:
--   { "lessons": [ { "number": 1, "title": "...",
--                    "blocks": [ { "type": "...", "tier": "...",
--                                  "section": "A" | null,
--                                  "body": { ... },
--                                  "answers": [...] (FULL only) } ] } ] }
create function public.publish_curriculum(
  p_church_id         uuid,
  p_definition        jsonb,
  p_content_level     public.curriculum_content_level,
  p_licence_reference text,
  p_published_by      uuid
)
returns table (publication_id uuid, version integer)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_curriculum uuid;
  v_lessons    integer;
  v_version    integer;
  v_pub        uuid;
  v_lesson     jsonb;
  v_lesson_id  uuid;
  v_block      jsonb;
  v_block_id   uuid;
  v_ordinal    integer;
  v_titles     jsonb := '[]'::jsonb;
  v_now        timestamptz := now();
begin
  select c.id into v_curriculum
  from public.curricula c
  where c.church_id = p_church_id
    and c.status = 'ACTIVE';

  if v_curriculum is null then
    raise exception 'invalid_curriculum_definition'
      using errcode = 'PT400', detail = 'The church has no ACTIVE curriculum.';
  end if;

  if jsonb_typeof(p_definition -> 'lessons') is distinct from 'array' then
    raise exception 'invalid_curriculum_definition'
      using errcode = 'PT400', detail = '"lessons" must be a list.';
  end if;

  select count(*) into v_lessons
  from public.curriculum_lessons l
  where l.curriculum_id = v_curriculum;

  if jsonb_array_length(p_definition -> 'lessons') <> v_lessons
     or exists (
       select 1
       from jsonb_array_elements(p_definition -> 'lessons') with ordinality as d(lesson, n)
       where (d.lesson ->> 'number')::integer is distinct from n::integer
          or not exists (
               select 1 from public.curriculum_lessons l
               where l.curriculum_id = v_curriculum
                 and l.lesson_number = n::integer
             )
          or length(trim(coalesce(d.lesson ->> 'title', ''))) = 0
          or jsonb_typeof(d.lesson -> 'blocks') is distinct from 'array'
     ) then
    raise exception 'invalid_curriculum_definition'
      using errcode = 'PT400',
            detail = format('Every one of the %s lessons, numbered in order, with a title and a list of blocks.', v_lessons);
  end if;

  update public.curriculum_publications p
  set superseded_at = v_now
  where p.curriculum_id = v_curriculum
    and p.superseded_at is null;

  select coalesce(max(p.version), 0) + 1 into v_version
  from public.curriculum_publications p
  where p.curriculum_id = v_curriculum;

  insert into public.curriculum_publications
    (curriculum_id, version, content_level, licence_reference,
     published_by, published_at)
  values
    (v_curriculum, v_version, p_content_level,
     nullif(trim(coalesce(p_licence_reference, '')), ''),
     p_published_by, v_now)
  returning id into v_pub;

  for v_lesson in select value from jsonb_array_elements(p_definition -> 'lessons')
  loop
    select l.id into v_lesson_id
    from public.curriculum_lessons l
    where l.curriculum_id = v_curriculum
      and l.lesson_number = (v_lesson ->> 'number')::integer;

    -- The title identifies the lesson; changing it touches no column
    -- that progress or meetings key on (ADR-010 decision 6).
    update public.curriculum_lessons l
    set title = trim(v_lesson ->> 'title')
    where l.id = v_lesson_id
      and l.title is distinct from trim(v_lesson ->> 'title');
    if found then
      v_titles := v_titles || jsonb_build_object(
        'lesson_number', (v_lesson ->> 'number')::integer,
        'title', trim(v_lesson ->> 'title'));
    end if;

    v_ordinal := 0;
    for v_block in select value from jsonb_array_elements(v_lesson -> 'blocks')
    loop
      v_ordinal := v_ordinal + 1;

      if v_block ? 'answers' and p_content_level <> 'FULL' then
        raise exception 'invalid_curriculum_definition'
          using errcode = 'PT400',
                detail = 'Answers are published only in a FULL publication.';
      end if;

      insert into public.lesson_content_blocks
        (publication_id, lesson_id, ordinal, section_label, block_type,
         tier, body)
      values
        (v_pub, v_lesson_id, v_ordinal,
         nullif(trim(coalesce(v_block ->> 'section', '')), ''),
         (v_block ->> 'type')::public.lesson_block_type,
         (v_block ->> 'tier')::public.content_tier,
         coalesce(v_block -> 'body', '{}'::jsonb))
      returning id into v_block_id;

      if v_block ? 'answers' then
        insert into public.lesson_block_answers (block_id, answers)
        values (v_block_id, v_block -> 'answers');
      end if;
    end loop;
  end loop;

  insert into public.audit_events
    (church_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    p_church_id,
    p_published_by,
    'CURRICULUM_PUBLISHED',
    'curriculum_publications',
    v_pub,
    jsonb_build_object(
      'version', v_version,
      'content_level', p_content_level,
      'licence_reference', nullif(trim(coalesce(p_licence_reference, '')), ''),
      'titles_changed', v_titles
    )
  );

  return query select v_pub, v_version;
end;
$$;

comment on function public.publish_curriculum(uuid, jsonb, public.curriculum_content_level, text, uuid) is
  'Trusted publishing tooling (service_role only). Publishes a curriculum definition as a new publication, superseding the current one. METADATA holds identifying blocks only; FULL requires a licence reference (ADR-019). Audited as CURRICULUM_PUBLISHED.';

revoke execute on function public.publish_curriculum(uuid, jsonb, public.curriculum_content_level, text, uuid)
  from public, anon, authenticated;
grant execute on function public.publish_curriculum(uuid, jsonb, public.curriculum_content_level, text, uuid)
  to service_role;


-- One lesson's current content for the caller, in the context of a
-- person (or themselves). Only the tiers the caller may read are
-- returned; answers only with the Discipler tier. A lesson the caller
-- may not read at all, an unknown lesson and someone else's church are
-- refused alike.
create function public.get_lesson_content(
  p_lesson_id         uuid,
  p_for_membership_id uuid default null
)
returns table (
  block_id      uuid,
  ordinal       integer,
  section_label text,
  block_type    public.lesson_block_type,
  tier          public.content_tier,
  body          jsonb,
  answers       jsonb,
  version       integer,
  content_level public.curriculum_content_level
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_disciple  boolean;
  v_discipler boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  v_disciple  := private.can_read_lesson_tier(p_lesson_id, 'DISCIPLE', p_for_membership_id);
  v_discipler := private.can_read_lesson_tier(p_lesson_id, 'DISCIPLER', p_for_membership_id);

  if not (v_disciple or v_discipler) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
    select b.id, b.ordinal, b.section_label, b.block_type, b.tier, b.body,
           case when v_discipler then a.answers end,
           p.version, p.content_level
    from public.lesson_content_blocks b
    join public.curriculum_publications p on p.id = b.publication_id
    left join public.lesson_block_answers a on a.block_id = b.id
    where b.lesson_id = p_lesson_id
      and p.superseded_at is null
      and ((b.tier = 'DISCIPLE' and v_disciple)
           or (b.tier = 'DISCIPLER' and v_discipler))
    order by b.ordinal;
end;
$$;

comment on function public.get_lesson_content(uuid, uuid) is
  'The current publication''s blocks of one lesson that the caller may read, in the context of p_for_membership_id (or themselves). ADR-019 decision 6.';


-- The lesson list with what the caller may read of each, in the
-- context of a person (or themselves). Asking about someone the caller
-- has no relationship with is refused rather than answered with locks.
create function public.list_lesson_access(p_for_membership_id uuid default null)
returns table (
  lesson_id      uuid,
  lesson_number  integer,
  title          text,
  theme          text,
  disciple_tier  boolean,
  discipler_tier boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_church uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if p_for_membership_id is null then
    select m.church_id into v_church
    from public.church_memberships m
    where m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
    limit 1;
  else
    select m.church_id into v_church
    from public.church_memberships m
    where m.id = p_for_membership_id;

    if v_church is null or not (
      private.is_church_coordinator(v_church)
      or private.is_my_membership(p_for_membership_id)
      or private.is_assigned_discipler_of(p_for_membership_id)
      or private.leads_current_group_of_disciple(p_for_membership_id)
    ) then
      raise exception 'not_authorized' using errcode = 'PT403';
    end if;
  end if;

  if v_church is null or not private.is_active_member_of(v_church) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  return query
    with access as (
      select l.id, l.lesson_number, l.title,
             private.can_read_lesson_tier(l.id, 'DISCIPLE', p_for_membership_id) as dt,
             private.can_read_lesson_tier(l.id, 'DISCIPLER', p_for_membership_id) as rt
      from public.curricula c
      join public.curriculum_lessons l on l.curriculum_id = c.id
      where c.church_id = v_church
        and c.status = 'ACTIVE'
    )
    select a.id, a.lesson_number, a.title,
           case when a.dt or a.rt then (
             select b.body ->> 'text'
             from public.lesson_content_blocks b
             join public.curriculum_publications p on p.id = b.publication_id
             where b.lesson_id = a.id
               and p.superseded_at is null
               and b.block_type = 'LESSON_THEME'
             order by b.ordinal
             limit 1
           ) end,
           a.dt, a.rt
    from access a
    order by a.lesson_number;
end;
$$;

comment on function public.list_lesson_access(uuid) is
  'Every lesson of the church''s ACTIVE curriculum with the tiers the caller may read, in the context of p_for_membership_id (or themselves). Refused for a person the caller has no relationship with. ADR-019 decision 6.';


-- Everything the caller may read right now, for the device copy
-- (ADR-019 decision 7): the union over the caller themselves, each
-- person they currently disciple, each active Disciple of a group they
-- lead, and, for the Coordinator, every lesson. One row per block,
-- with answers only where the Discipler tier is allowed.
create function public.get_my_readable_content()
returns table (
  lesson_id     uuid,
  block_id      uuid,
  ordinal       integer,
  section_label text,
  block_type    public.lesson_block_type,
  tier          public.content_tier,
  body          jsonb,
  answers       jsonb,
  version       integer,
  content_level public.curriculum_content_level
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  return query
    with me as (
      select m.id, m.church_id
      from public.church_memberships m
      where m.user_id = v_uid and m.status = 'ACTIVE'
    ),
    contexts as (
      -- myself
      select me.id as for_id from me
      union
      -- people I currently disciple
      select dd.church_membership_id
      from public.discipler_assignments a
      join public.d_group_memberships dr on dr.id = a.discipler_d_group_membership_id
      join public.d_group_memberships dd on dd.id = a.disciple_d_group_membership_id
      join me on me.id = dr.church_membership_id
      where a.ended_at is null and dr.ended_at is null and dd.ended_at is null
      union
      -- active Disciples of a group I lead
      select dd.church_membership_id
      from public.d_group_memberships l
      join me on me.id = l.church_membership_id
      join public.d_group_memberships dd on dd.d_group_id = l.d_group_id
      where l.responsibility = 'LEADER' and l.ended_at is null
        and dd.responsibility = 'DISCIPLE' and dd.ended_at is null
    ),
    lessons as (
      select l.id
      from me
      join public.curricula c on c.church_id = me.church_id and c.status = 'ACTIVE'
      join public.curriculum_lessons l on l.curriculum_id = c.id
    ),
    allowed as (
      select le.id as lesson_id,
             bool_or(private.can_read_lesson_tier(le.id, 'DISCIPLE', ctx.for_id))
               or bool_or(private.can_read_lesson_tier(le.id, 'DISCIPLE', null)) as dt,
             bool_or(private.can_read_lesson_tier(le.id, 'DISCIPLER', ctx.for_id))
               or bool_or(private.can_read_lesson_tier(le.id, 'DISCIPLER', null)) as rt
      from lessons le
      cross join contexts ctx
      group by le.id
    )
    select b.lesson_id, b.id, b.ordinal, b.section_label, b.block_type,
           b.tier, b.body,
           case when al.rt then an.answers end,
           p.version, p.content_level
    from allowed al
    join public.lesson_content_blocks b on b.lesson_id = al.lesson_id
    join public.curriculum_publications p on p.id = b.publication_id
    left join public.lesson_block_answers an on an.block_id = b.id
    where p.superseded_at is null
      and ((b.tier = 'DISCIPLE' and al.dt) or (b.tier = 'DISCIPLER' and al.rt))
    order by b.lesson_id, b.ordinal;
end;
$$;

comment on function public.get_my_readable_content() is
  'Every block the caller may read now, across their own journey, the people they disciple, the active Disciples of a group they lead and (Coordinator) every lesson. For the device copy, which is pruned to this on each refresh (ADR-019 decision 7).';


do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.get_lesson_content(uuid, uuid)',
    'public.list_lesson_access(uuid)',
    'public.get_my_readable_content()'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated, service_role', v_fn);
  end loop;
end
$$;
