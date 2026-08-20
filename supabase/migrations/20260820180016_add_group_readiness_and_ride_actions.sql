-- Group readiness is authoritative in Postgres so a stale or modified client
-- cannot start a shared ride before every joined rider is ready.

alter table public.shared_ride_members
  add column if not exists is_ready boolean not null default false,
  add column if not exists ready_at timestamptz;

alter table public.shared_ride_members
  drop constraint if exists shared_ride_members_readiness_valid,
  add constraint shared_ride_members_readiness_valid check (
    (is_ready and ready_at is not null)
    or (not is_ready and ready_at is null)
  );

grant update (is_ready, ready_at) on table public.shared_ride_members
  to authenticated;

create or replace function public.start_shared_ride(p_shared_ride_id uuid)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  started_time timestamptz := clock_timestamp();
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in before starting a shared ride.' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.shared_rides ride
    where ride.shared_ride_id = p_shared_ride_id
      and ride.leader_id = (select auth.uid())
      and ride.status = 'planned'
  ) then
    raise exception 'Only the leader can start an open shared ride.' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.shared_ride_members member
    where member.shared_ride_id = p_shared_ride_id
      and member.status = 'joined'
  ) then
    raise exception 'The shared ride has no joined riders.' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.shared_ride_members member
    where member.shared_ride_id = p_shared_ride_id
      and member.status = 'joined'
      and not member.is_ready
  ) then
    raise exception 'Everyone must be ready before the leader can start.' using errcode = '23514';
  end if;

  update public.shared_rides
  set status = 'active', started_at = started_time
  where shared_ride_id = p_shared_ride_id
    and leader_id = (select auth.uid())
    and status = 'planned';

  if not found then
    raise exception 'The shared ride could not be started.' using errcode = 'P0002';
  end if;

  return started_time;
end;
$$;

revoke all on function public.start_shared_ride(uuid)
  from public, anon, authenticated;
grant execute on function public.start_shared_ride(uuid) to authenticated;

create table public.shared_ride_events (
  event_id uuid primary key default gen_random_uuid(),
  shared_ride_id uuid not null
    references public.shared_rides (shared_ride_id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  action text not null,
  created_at timestamptz not null default now(),
  constraint shared_ride_events_action_valid check (
    action in ('stopping', 'fuel', 'food', 'regroup', 'danger')
  )
);

create index shared_ride_events_group_created_idx
  on public.shared_ride_events (shared_ride_id, created_at desc);

alter table public.shared_ride_events enable row level security;
revoke all on table public.shared_ride_events from public, anon, authenticated;
grant select, insert on table public.shared_ride_events to authenticated;

create policy "Members can read shared ride actions"
on public.shared_ride_events for select to authenticated
using (private.is_shared_ride_member(shared_ride_id));

create policy "Members can send shared ride actions"
on public.shared_ride_events for insert to authenticated
with check (
  user_id = (select auth.uid())
  and private.is_shared_ride_member(shared_ride_id)
  and exists (
    select 1
    from public.shared_rides ride
    where ride.shared_ride_id = shared_ride_events.shared_ride_id
      and ride.status = 'active'
  )
);

comment on column public.shared_ride_members.is_ready is
  'Must be true for every joined member before the leader can start.';
comment on table public.shared_ride_events is
  'Short, member-only in-ride signals such as fuel, regroup, or danger.';
