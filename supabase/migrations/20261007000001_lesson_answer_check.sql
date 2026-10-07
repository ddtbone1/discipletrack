-- Migration 020: checking a Disciple's blanks (user decision 2026-10-07,
-- ADR-021 amendment).
--
-- A Disciple answers a lesson's blanks in the app (kept on their device,
-- ADR-021) and taps Check. This function compares what they wrote with the
-- book's answers and says, per blank, whether it is right, with the
-- book's answer. It returns answers only for the blocks and blanks the
-- caller submitted, and only to someone who may read that lesson's
-- Disciple tier in their own context. Nothing is stored: it is not a
-- grade and never counts as progress (ADR-011, ADR-015).
--
-- Matching ignores case, spacing and punctuation. An entry of the answer
-- key may list several accepted answers; a blank the book leaves without
-- an answer is not checked.

create function private.normalize_answer(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(regexp_replace(
    regexp_replace(lower(coalesce(p_text, '')), '[^[:alnum:][:space:]]', '', 'g'),
    '\s+', ' ', 'g'
  ));
$$;

create function public.check_lesson_answers(
  p_lesson_id uuid,
  p_responses jsonb
)
returns table (
  block_id uuid,
  blank    integer,
  correct  boolean,
  answer   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = 'PT401';
  end if;

  if not private.can_read_lesson_tier(p_lesson_id, 'DISCIPLE', null) then
    raise exception 'not_authorized' using errcode = 'PT403';
  end if;

  if p_responses is null or jsonb_typeof(p_responses) <> 'object' then
    raise exception 'invalid_responses'
      using errcode = 'PT400',
            detail = 'Responses are an object of block id to a list of answers.';
  end if;

  return query
    with submitted as (
      select (r.key)::uuid as block_id,
             s.ordinality::integer - 1 as blank,
             s.value as given
      from jsonb_each(p_responses) r
      cross join lateral jsonb_array_elements_text(
        case when jsonb_typeof(r.value) = 'array' then r.value else '[]'::jsonb end
      ) with ordinality s
      where r.key ~ '^[0-9a-f-]{36}$'
        -- Only what was written: an empty blank reveals nothing.
        and btrim(s.value) <> ''
    ),
    keyed as (
      select su.block_id, su.blank, su.given, a.answers -> su.blank as entry
      from submitted su
      join public.lesson_content_blocks b on b.id = su.block_id
      join public.curriculum_publications p on p.id = b.publication_id
      join public.lesson_block_answers a on a.block_id = b.id
      where b.lesson_id = p_lesson_id
        and p.superseded_at is null
        and b.tier = 'DISCIPLE'
        and b.block_type not in ('VERSE_WRITING', 'FIGURE')
        and su.blank < jsonb_array_length(a.answers)
    ),
    accepted as (
      select k.block_id, k.blank, k.given,
             case when jsonb_typeof(k.entry) = 'array'
                  then array(select jsonb_array_elements_text(k.entry))
                  else array[k.entry #>> '{}']
             end as options
      from keyed k
    )
    select ac.block_id, ac.blank,
           private.normalize_answer(ac.given) = any (
             select private.normalize_answer(o) from unnest(ac.options) o
           ),
           ac.options[1]
    from accepted ac
    where coalesce(ac.options[1], '') <> ''
    order by ac.block_id, ac.blank;
end;
$$;

revoke execute on function public.check_lesson_answers(uuid, jsonb) from public, anon;
grant execute on function public.check_lesson_answers(uuid, jsonb) to authenticated;
revoke execute on function private.normalize_answer(text) from public, anon, authenticated;

comment on function public.check_lesson_answers(uuid, jsonb) is
  'Checks the caller''s own blanks of one lesson against the book''s answers: per submitted blank, right or not and the answer. Nothing is stored. Migration 020, ADR-021.';
