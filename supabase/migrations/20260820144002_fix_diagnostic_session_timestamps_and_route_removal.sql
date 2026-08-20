-- Keep diagnostic completion timestamps authoritative to PostgreSQL. Mobile
-- device clocks can be behind the server clock, which previously allowed an
-- update to violate diagnostic_sessions_dates_valid.

-- Close only stale, non-ride checks left unfinished by the former constraint
-- error. Active ride sessions are intentionally untouched. This runs before
-- the server-time trigger so these failed attempts retain a zero duration.
update public.diagnostic_sessions
set
  ended_at = started_at,
  score_details = score_details || jsonb_build_object(
    'issues', jsonb_build_array(
      'Diagnostic ended before its results could be saved.'
    ),
    'scoring_version', 'rules-v1',
    'ai_generated', false
  )
where ended_at is null
  and session_type <> 'ride'
  and started_at < clock_timestamp() - interval '1 hour';

create or replace function public.set_diagnostic_session_completion_time()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.ended_at is not null then
    if old.ended_at is null then
      new.ended_at := greatest(clock_timestamp(), new.started_at);
    else
      new.ended_at := greatest(new.ended_at, new.started_at);
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.set_diagnostic_session_completion_time()
  from public, anon, authenticated;

drop trigger if exists set_diagnostic_session_completion_time
  on public.diagnostic_sessions;

create trigger set_diagnostic_session_completion_time
before update of ended_at on public.diagnostic_sessions
for each row execute function public.set_diagnostic_session_completion_time();

-- Planned-route archive and permanent deletion already use the existing
-- owner-scoped UPDATE and DELETE policies on public.route_plans. No broader
-- database privilege is added for the swipe actions.
