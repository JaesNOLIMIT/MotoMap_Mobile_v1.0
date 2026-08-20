-- Phase 3 route customization and private pre-ride groups.
-- A group is invisible unless the signed-in rider is already a member. The
-- six-character code can only be exchanged through join_shared_ride().

alter table public.route_plans
  add column if not exists motorcycle_id uuid,
  add column if not exists waypoints jsonb not null default '[]'::jsonb,
  add column if not exists departure_mode text not null default 'now',
  add column if not exists avoid_highways boolean not null default false,
  add column if not exists avoid_tolls boolean not null default false;

alter table public.route_plans
  drop constraint if exists route_plans_motorcycle_owner_fk,
  add constraint route_plans_motorcycle_owner_fk
    foreign key (motorcycle_id, user_id)
    references public.motorcycles (motorcycle_id, user_id)
    on delete set null (motorcycle_id),
  drop constraint if exists route_plans_waypoints_valid,
  add constraint route_plans_waypoints_valid
    check (jsonb_typeof(waypoints) = 'array'),
  drop constraint if exists route_plans_departure_mode_valid,
  add constraint route_plans_departure_mode_valid
    check (departure_mode in ('now', 'later')),
  drop constraint if exists route_plans_departure_schedule_valid,
  add constraint route_plans_departure_schedule_valid
    check (
      (departure_mode = 'now' and scheduled_for is null)
      or (departure_mode = 'later' and scheduled_for is not null)
    );

create table public.shared_rides (
  shared_ride_id uuid primary key default gen_random_uuid(),
  route_plan_id uuid not null,
  leader_id uuid not null references auth.users (id) on delete cascade,
  join_code text not null unique,
  status text not null default 'planned',
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_rides_route_owner_fk
    foreign key (route_plan_id, leader_id)
    references public.route_plans (route_plan_id, user_id)
    on delete cascade,
  constraint shared_rides_route_unique unique (route_plan_id),
  constraint shared_rides_join_code_valid check (
    join_code ~ '^[A-Z0-9]{6}$'
  ),
  constraint shared_rides_status_valid check (
    status in ('planned', 'active', 'ended', 'cancelled')
  ),
  constraint shared_rides_dates_valid check (
    (started_at is null or started_at >= created_at)
    and (ended_at is null or (started_at is not null and ended_at >= started_at))
  )
);

create table public.shared_ride_members (
  shared_ride_id uuid not null
    references public.shared_rides (shared_ride_id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  motorcycle_id uuid,
  role text not null default 'member',
  status text not null default 'joined',
  rider_name text not null,
  rider_avatar_path text,
  motorcycle_name text,
  motorcycle_photo_path text,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shared_ride_id, user_id),
  constraint shared_ride_members_motorcycle_owner_fk
    foreign key (motorcycle_id, user_id)
    references public.motorcycles (motorcycle_id, user_id)
    on delete set null (motorcycle_id),
  constraint shared_ride_members_role_valid check (role in ('leader', 'member')),
  constraint shared_ride_members_status_valid check (status in ('joined', 'left')),
  constraint shared_ride_members_rider_name_valid check (
    char_length(btrim(rider_name)) between 1 and 120
  )
);

create index shared_ride_members_user_idx
  on public.shared_ride_members (user_id, status, joined_at desc);
create index shared_ride_members_group_idx
  on public.shared_ride_members (shared_ride_id, status, joined_at);

create or replace function private.assign_shared_ride_code()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
begin
  if new.join_code is not null and new.join_code <> '' then
    new.join_code := upper(new.join_code);
    return new;
  end if;
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1), '')
      into candidate
    from generate_series(1, 6);
    exit when not exists (
      select 1 from public.shared_rides where join_code = candidate
    );
  end loop;
  new.join_code := candidate;
  return new;
end;
$$;

create or replace function private.populate_shared_ride_member_preview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_row public.profiles%rowtype;
  bike_row public.motorcycles%rowtype;
begin
  select * into strict profile_row
  from public.profiles where user_id = new.user_id;
  new.rider_name := btrim(profile_row.first_name || ' ' || profile_row.last_name);
  new.rider_avatar_path := profile_row.avatar_path;
  if new.motorcycle_id is not null then
    select * into strict bike_row
    from public.motorcycles
    where motorcycle_id = new.motorcycle_id and user_id = new.user_id;
    new.motorcycle_name := bike_row.make || ' ' || bike_row.model;
    new.motorcycle_photo_path := bike_row.photo_path;
  else
    new.motorcycle_name := null;
    new.motorcycle_photo_path := null;
  end if;
  return new;
end;
$$;

create or replace function private.is_shared_ride_member(p_shared_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shared_ride_members member
    where member.shared_ride_id = p_shared_ride_id
      and member.user_id = (select auth.uid())
      and member.status = 'joined'
  );
$$;

create trigger shared_rides_assign_code
before insert on public.shared_rides
for each row execute function private.assign_shared_ride_code();

create trigger shared_rides_set_updated_at
before update on public.shared_rides
for each row execute function private.set_profile_updated_at();

create trigger shared_ride_members_populate_preview
before insert or update of motorcycle_id on public.shared_ride_members
for each row execute function private.populate_shared_ride_member_preview();

create trigger shared_ride_members_set_updated_at
before update on public.shared_ride_members
for each row execute function private.set_profile_updated_at();

alter table public.shared_rides enable row level security;
alter table public.shared_ride_members enable row level security;

revoke all on table public.shared_rides from public, anon, authenticated;
revoke all on table public.shared_ride_members from public, anon, authenticated;
grant select, insert, update, delete on table public.shared_rides to authenticated;
grant select, insert, delete on table public.shared_ride_members to authenticated;
grant update (motorcycle_id, status) on table public.shared_ride_members to authenticated;

grant usage on schema private to authenticated;
revoke all on function private.assign_shared_ride_code() from public, anon, authenticated;
revoke all on function private.populate_shared_ride_member_preview() from public, anon, authenticated;
revoke all on function private.is_shared_ride_member(uuid) from public, anon, authenticated;
grant execute on function private.is_shared_ride_member(uuid) to authenticated;

create policy "Members can read their shared rides"
on public.shared_rides for select to authenticated
using (private.is_shared_ride_member(shared_ride_id));

create policy "Leaders can create shared rides"
on public.shared_rides for insert to authenticated
with check (
  leader_id = (select auth.uid())
  and exists (
    select 1 from public.route_plans route
    where route.route_plan_id = shared_rides.route_plan_id
      and route.user_id = (select auth.uid())
  )
);

create policy "Leaders can update shared rides"
on public.shared_rides for update to authenticated
using (leader_id = (select auth.uid()))
with check (leader_id = (select auth.uid()));

create policy "Leaders can delete shared rides"
on public.shared_rides for delete to authenticated
using (leader_id = (select auth.uid()));

create policy "Members can read group members"
on public.shared_ride_members for select to authenticated
using (private.is_shared_ride_member(shared_ride_id));

create policy "Group members can read the shared route plan"
on public.route_plans for select to authenticated
using (
  exists (
    select 1 from public.shared_rides shared
    where shared.route_plan_id = route_plans.route_plan_id
      and private.is_shared_ride_member(shared.shared_ride_id)
  )
);

create policy "Leaders can add themselves"
on public.shared_ride_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'leader'
  and exists (
    select 1 from public.shared_rides ride
    where ride.shared_ride_id = shared_ride_members.shared_ride_id
      and ride.leader_id = (select auth.uid())
  )
);

create policy "Members can update their preview"
on public.shared_ride_members for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "Members can leave shared rides"
on public.shared_ride_members for delete to authenticated
using (user_id = (select auth.uid()) and role = 'member');

create or replace function public.create_shared_ride(
  p_route_plan_id uuid,
  p_motorcycle_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rider_id uuid := auth.uid();
  target_id uuid;
begin
  if rider_id is null then
    raise exception 'Sign in before creating a shared ride.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.route_plans route
    where route.route_plan_id = p_route_plan_id and route.user_id = rider_id
  ) then
    raise exception 'Choose one of your saved rides.' using errcode = '42501';
  end if;
  if p_motorcycle_id is not null and not exists (
    select 1 from public.motorcycles bike
    where bike.motorcycle_id = p_motorcycle_id and bike.user_id = rider_id
  ) then
    raise exception 'Choose one of your motorcycles.' using errcode = '42501';
  end if;
  insert into public.shared_rides (route_plan_id, leader_id, join_code)
  values (p_route_plan_id, rider_id, '')
  on conflict (route_plan_id) do update set updated_at = clock_timestamp()
  returning shared_ride_id into target_id;

  insert into public.shared_ride_members (
    shared_ride_id, user_id, motorcycle_id, role, status, rider_name
  ) values (
    target_id, rider_id, p_motorcycle_id, 'leader', 'joined', 'Rider'
  )
  on conflict (shared_ride_id, user_id) do update
    set motorcycle_id = excluded.motorcycle_id, status = 'joined';
  return target_id;
end;
$$;

create or replace function public.join_shared_ride(
  p_join_code text,
  p_motorcycle_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rider_id uuid := auth.uid();
  target_id uuid;
begin
  if rider_id is null then
    raise exception 'Sign in before joining a shared ride.' using errcode = '42501';
  end if;
  if upper(btrim(p_join_code)) !~ '^[A-Z0-9]{6}$' then
    raise exception 'Enter the six-character shared ride code.' using errcode = '22023';
  end if;
  select ride.shared_ride_id into target_id
  from public.shared_rides ride
  where ride.join_code = upper(btrim(p_join_code))
    and ride.status = 'planned';
  if target_id is null then
    raise exception 'That shared ride code is invalid or no longer open.' using errcode = 'P0002';
  end if;
  if p_motorcycle_id is not null and not exists (
    select 1 from public.motorcycles bike
    where bike.motorcycle_id = p_motorcycle_id and bike.user_id = rider_id
  ) then
    raise exception 'Choose one of your motorcycles.' using errcode = '42501';
  end if;
  insert into public.shared_ride_members (
    shared_ride_id, user_id, motorcycle_id, role, status, rider_name
  ) values (
    target_id, rider_id, p_motorcycle_id, 'member', 'joined', 'Rider'
  )
  on conflict (shared_ride_id, user_id) do update
    set motorcycle_id = excluded.motorcycle_id, status = 'joined';
  return target_id;
end;
$$;

revoke all on function public.join_shared_ride(text, uuid)
  from public, anon, authenticated;
revoke all on function public.create_shared_ride(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.join_shared_ride(text, uuid)
  to authenticated;
grant execute on function public.create_shared_ride(uuid, uuid)
  to authenticated;

comment on table public.shared_rides is
  'Private pre-ride groups discoverable only through a six-character join code.';
comment on table public.shared_ride_members is
  'Member-safe rider and motorcycle preview snapshots for a private shared ride.';
