-- ============================================================
-- DiscipleTrack - Migration 019: faithful lesson content (Slice 7)
-- ============================================================
--
-- ADR-019, amended 2026-10-06 (decisions 11 to 15): permission to
-- reproduce the curriculum is confirmed, and the lessons are published
-- faithfully, as one canonical block sequence per lesson in source
-- order, with two presentations (Disciple: blanks unanswered; Discipler:
-- answers shown).
--
-- New block types, for structures the lessons contain:
--   POINT        a bulleted item, optionally led by a scripture reference
--                { "reference"?, "text" }
--   FIGURE       a chart or picture, with its caption and labels
--                { "caption" }
--   SELF_CHECK   the self-rating table { "columns": [...], "items": [...] }
--   SIGN_OFF     date and signature lines { "text" }
--   ASSIGNMENT   a numbered assignment { "number", "text" }
--   LIST         a plain list inside an assignment { "items": [...] }
--   HEADING      a page banner such as "Reflect & Transfer" or "Daily in
--                the Word" { "title", "subtitle"? }
--
-- Blanks: a blank is written "[_]" inside a block's text, and the body
-- carries "blanks", their count (for VERSE_WRITING and FIGURE, the number
-- of answer lines or labels). Answers, one per blank, stay in
-- lesson_block_answers and reach a client only with the Discipler tier
-- (Migration 017). The answers trigger now requires the count to match,
-- for any block type that declares blanks; a FILL_IN block without a
-- count is accepted as before.
--
-- Migrations 001 to 018 are not modified.
-- ============================================================

alter type public.lesson_block_type add value if not exists 'POINT';
alter type public.lesson_block_type add value if not exists 'FIGURE';
alter type public.lesson_block_type add value if not exists 'SELF_CHECK';
alter type public.lesson_block_type add value if not exists 'SIGN_OFF';
alter type public.lesson_block_type add value if not exists 'ASSIGNMENT';
alter type public.lesson_block_type add value if not exists 'LIST';
alter type public.lesson_block_type add value if not exists 'HEADING';


-- As Migration 017, with the new types' required keys and the blanks
-- count checked.
create or replace function private.check_lesson_content_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pub public.curriculum_publications%rowtype;
  v_required text;
  v_type text := new.block_type::text;
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

  if v_pub.content_level = 'METADATA' and v_type not in (
    'LESSON_THEME', 'TOPIC_LIST', 'SECTION_HEADING',
    'SCRIPTURE_REFERENCES', 'MODULE_HEADING'
  ) then
    raise exception 'content_block_not_metadata'
      using errcode = '23514',
            detail = 'A METADATA publication holds identifying blocks only (ADR-019 decision 2).';
  end if;

  if v_type in ('MODULE_HEADING', 'DISCIPLER_NOTE')
     and new.tier <> 'DISCIPLER' then
    raise exception 'content_block_tier_invalid'
      using errcode = '23514',
            detail = 'Training modules and Discipler notes are Discipler tier.';
  end if;

  v_required := case v_type
    when 'TOPIC_LIST'           then 'items'
    when 'DISCUSSION_PROMPTS'   then 'items'
    when 'ASSIGNMENTS'          then 'items'
    when 'SELF_CHECK'           then 'items'
    when 'LIST'                 then 'items'
    when 'SCRIPTURE_REFERENCES' then 'refs'
    when 'VERSE_WRITING'        then 'reference'
    when 'MODULE_HEADING'       then 'title'
    when 'FIGURE'               then 'caption'
    when 'HEADING'              then 'title'
    when 'SECTION_HEADING'      then null   -- a section may be known by its label only
    else 'text'
  end;

  if v_required is not null and not (new.body ? v_required) then
    raise exception 'content_block_body_invalid'
      using errcode = '23514',
            detail = format('A %s block needs a "%s" key.', v_type, v_required);
  end if;

  if v_type in ('TOPIC_LIST', 'DISCUSSION_PROMPTS', 'ASSIGNMENTS',
                'SCRIPTURE_REFERENCES', 'SELF_CHECK', 'LIST')
     and jsonb_typeof(new.body -> v_required) <> 'array' then
    raise exception 'content_block_body_invalid'
      using errcode = '23514',
            detail = format('"%s" of a %s block is a list.', v_required, v_type);
  end if;

  if new.body ? 'blanks' and not (
    jsonb_typeof(new.body -> 'blanks') = 'number'
    and (new.body ->> 'blanks')::numeric >= 0
    and (new.body ->> 'blanks')::numeric = trunc((new.body ->> 'blanks')::numeric)
  ) then
    raise exception 'content_block_body_invalid'
      using errcode = '23514',
            detail = '"blanks" is a whole number of blanks.';
  end if;

  return null;
end;
$$;


-- As Migration 017, generalized: answers belong to a block of a FULL
-- publication, and when the block declares its blanks there is exactly
-- one answer per blank.
create or replace function private.check_lesson_block_answers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_block public.lesson_content_blocks%rowtype;
  v_level public.curriculum_content_level;
begin
  select b.* into v_block
  from public.lesson_content_blocks b
  where b.id = new.block_id;

  select p.content_level into v_level
  from public.curriculum_publications p
  where p.id = v_block.publication_id;

  if v_level is distinct from 'FULL' then
    raise exception 'answers_block_invalid'
      using errcode = '23514',
            detail = 'Answers belong to blocks of a FULL publication.';
  end if;

  if v_block.body ? 'blanks' then
    if jsonb_array_length(new.answers) <> (v_block.body ->> 'blanks')::integer then
      raise exception 'answers_block_invalid'
        using errcode = '23514',
              detail = 'One answer per blank.';
    end if;
  elsif v_block.block_type::text <> 'FILL_IN' then
    raise exception 'answers_block_invalid'
      using errcode = '23514',
            detail = 'Answers belong to a block that declares its blanks.';
  end if;

  return null;
end;
$$;


-- ============================================================
-- Every Discipler reads every lesson (ADR-019 amended, decision 16)
-- ============================================================
--
-- User decision 2026-10-06: a Discipler (anyone holding an active
-- DISCIPLER responsibility in the church, every Leader included,
-- ADR-020) opens all lessons in both tiers, in their own view and in any
-- Disciple's, so they can prepare. Disciples stay gated by progression
-- (completed lessons and the current one). Leaders keep their own rule
-- for the Disciples of their group, and now hold DISCIPLER as well.

create function private.is_discipler_in_church(p_church_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.d_group_memberships dgm
    join public.church_memberships m on m.id = dgm.church_membership_id
    join public.d_groups g on g.id = dgm.d_group_id
    where m.user_id = (select auth.uid())
      and m.status = 'ACTIVE'
      and m.church_id = p_church_id
      and g.church_id = p_church_id
      and dgm.responsibility = 'DISCIPLER'
      and dgm.ended_at is null
  );
$$;

revoke execute on function private.is_discipler_in_church(uuid)
  from public, anon, authenticated;

-- As Migration 017, with the Discipler rule after the Coordinator's.
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

  if v_church is null then
    return false;
  end if;

  if private.is_church_coordinator(v_church) then
    return true;
  end if;

  if private.is_discipler_in_church(v_church) then
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


-- ============================================================
-- Lesson covers (user decision 2026-10-06)
-- ============================================================
--
-- Each lesson's cover photo from the book, shown behind its card in the
-- lesson list. Covers carry no lesson content, so every ACTIVE member of
-- the church may read them, open lessons and locked ones alike. Written
-- only by trusted tooling (tool/curriculum/build_covers.dart), like the
-- content; the image is a small JPEG, base64-encoded.

create table public.lesson_covers (
  lesson_id   uuid        not null,
  image       text        not null,
  mime_type   text        not null default 'image/jpeg',
  updated_at  timestamptz not null default now(),

  constraint lesson_covers_pkey primary key (lesson_id),
  constraint lesson_covers_lesson_fkey foreign key (lesson_id)
    references public.curriculum_lessons (id) on delete no action,
  constraint lesson_covers_mime_check check (mime_type in ('image/jpeg', 'image/png'))
);

comment on table public.lesson_covers is
  'The book''s cover photo of each lesson, for the lesson list. No client policy; read through get_lesson_covers(), written through set_lesson_cover() (service_role).';

alter table public.lesson_covers enable row level security;
revoke all on public.lesson_covers from anon, authenticated;

create function public.set_lesson_cover(
  p_lesson_id uuid,
  p_image     text,
  p_mime_type text default 'image/jpeg'
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.lesson_covers (lesson_id, image, mime_type)
  values (p_lesson_id, p_image, p_mime_type)
  on conflict (lesson_id) do update
    set image = excluded.image,
        mime_type = excluded.mime_type,
        updated_at = now();
$$;

revoke execute on function public.set_lesson_cover(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.set_lesson_cover(uuid, text, text)
  to service_role;

create function public.get_lesson_covers()
returns table (lesson_id uuid, image text, mime_type text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  return query
    select lc.lesson_id, lc.image, lc.mime_type
    from public.lesson_covers lc
    join public.curriculum_lessons l on l.id = lc.lesson_id
    join public.curricula c on c.id = l.curriculum_id and c.status = 'ACTIVE'
    join public.church_memberships m
      on m.church_id = c.church_id
     and m.user_id = (select auth.uid())
     and m.status = 'ACTIVE';
end;
$$;

revoke execute on function public.get_lesson_covers() from public, anon;
grant execute on function public.get_lesson_covers() to authenticated;
