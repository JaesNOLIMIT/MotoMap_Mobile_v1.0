-- Real route planning, GPS ride recording, pause history, navigation results,
-- ride scoring, and lifetime motorcycle usage for MotoMap.
--
-- Route geometry and maneuvers are stored as JSON so a saved plan remains
-- usable if the public routing provider is temporarily unavailable.

create table if not exists public.route_plans (
  route_plan_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  source text not null default 'manual',
  prompt text,
  origin_name text not null,
  origin_latitude numeric(9, 6) not null,
  origin_longitude numeric(9, 6) not null,
  destination_name text not null,
  destination_latitude numeric(9, 6) not null,
  destination_longitude numeric(9, 6) not null,
  is_loop boolean not null default false,
  requested_distance_km numeric(8, 2),
  requested_duration_minutes integer,
  route_preference text not null default 'balanced',
  distance_km numeric(10, 3) not null,
  duration_seconds integer not null,
  route_coordinates jsonb not null default '[]'::jsonb,
  maneuvers jsonb not null default '[]'::jsonb,
  routing_provider text not null default 'valhalla',
  routing_profile text not null default 'motorcycle',
  provider_metadata jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz,
  status text not null default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint route_plans_title_valid check (
    char_length(btrim(title)) between 1 and 120
  ),
  constraint route_plans_source_valid check (
    source in ('manual', 'smart_prompt', 'quick_idea')
  ),
  constraint route_plans_coordinates_valid check (
    origin_latitude between -90 and 90
    and destination_latitude between -90 and 90
    and origin_longitude between -180 and 180
    and destination_longitude between -180 and 180
  ),
  constraint route_plans_requested_distance_valid check (
    requested_distance_km is null
    or requested_distance_km between 1 and 5000
  ),
  constraint route_plans_requested_duration_valid check (
    requested_duration_minutes is null
    or requested_duration_minutes between 5 and 10080
  ),
  constraint route_plans_preference_valid check (
    route_preference in ('fastest', 'balanced', 'scenic', 'curvy')
  ),
  constraint route_plans_result_valid check (
    distance_km >= 0
    and duration_seconds >= 0
    and jsonb_typeof(route_coordinates) = 'array'
    and jsonb_typeof(maneuvers) = 'array'
  ),
  constraint route_plans_status_valid check (
    status in ('planned', 'completed', 'archived')
  ),
  unique (route_plan_id, user_id)
);

create index if not exists route_plans_user_status_created_idx
  on public.route_plans (user_id, status, created_at desc);

create index if not exists route_plans_user_scheduled_idx
  on public.route_plans (user_id, scheduled_for)
  where scheduled_for is not null and status = 'planned';

create table if not exists public.rides (
  ride_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  motorcycle_id uuid not null,
  route_plan_id uuid,
  diagnostic_session_id uuid,
  title text not null,
  status text not null default 'recording',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  elapsed_duration_seconds integer,
  moving_duration_seconds integer,
  paused_duration_seconds integer not null default 0,
  start_latitude numeric(9, 6),
  start_longitude numeric(9, 6),
  end_latitude numeric(9, 6),
  end_longitude numeric(9, 6),
  destination_latitude numeric(9, 6),
  destination_longitude numeric(9, 6),
  reached_destination boolean not null default false,
  distance_km numeric(12, 3) not null default 0,
  average_speed_kph numeric(7, 2),
  maximum_speed_kph numeric(7, 2),
  fuel_consumed_liters numeric(10, 4),
  fuel_is_estimated boolean not null default false,
  fuel_calculation_method text,
  completion_percent numeric(5, 2),
  riding_score smallint,
  motorcycle_health_score smallint,
  score_details jsonb not null default '{}'::jsonb,
  route_coordinates jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rides_motorcycle_owner_fk
    foreign key (motorcycle_id, user_id)
    references public.motorcycles (motorcycle_id, user_id)
    on delete cascade,
  constraint rides_route_plan_owner_fk
    foreign key (route_plan_id, user_id)
    references public.route_plans (route_plan_id, user_id)
    on delete set null (route_plan_id),
  constraint rides_diagnostic_session_owner_fk
    foreign key (diagnostic_session_id, motorcycle_id, user_id)
    references public.diagnostic_sessions (
      diagnostic_session_id,
      motorcycle_id,
      user_id
    )
    on delete set null (diagnostic_session_id),
  constraint rides_title_valid check (
    char_length(btrim(title)) between 1 and 120
  ),
  constraint rides_status_valid check (
    status in ('recording', 'paused', 'completed', 'discarded')
  ),
  constraint rides_dates_valid check (
    ended_at is null or ended_at >= started_at
  ),
  constraint rides_durations_valid check (
    (elapsed_duration_seconds is null or elapsed_duration_seconds >= 0)
    and (moving_duration_seconds is null or moving_duration_seconds >= 0)
    and paused_duration_seconds >= 0
  ),
  constraint rides_coordinates_valid check (
    (start_latitude is null or start_latitude between -90 and 90)
    and (end_latitude is null or end_latitude between -90 and 90)
    and (destination_latitude is null or destination_latitude between -90 and 90)
    and (start_longitude is null or start_longitude between -180 and 180)
    and (end_longitude is null or end_longitude between -180 and 180)
    and (destination_longitude is null or destination_longitude between -180 and 180)
  ),
  constraint rides_metrics_valid check (
    distance_km >= 0
    and (average_speed_kph is null or average_speed_kph between 0 and 500)
    and (maximum_speed_kph is null or maximum_speed_kph between 0 and 500)
    and (fuel_consumed_liters is null or fuel_consumed_liters >= 0)
    and (completion_percent is null or completion_percent between 0 and 100)
    and (riding_score is null or riding_score between 0 and 100)
    and (
      motorcycle_health_score is null
      or motorcycle_health_score between 0 and 100
    )
    and jsonb_typeof(route_coordinates) = 'array'
  ),
  constraint rides_fuel_method_valid check (
    fuel_calculation_method is null
    or fuel_calculation_method in ('obd_pid_5e', 'distance_estimate')
  ),
  unique (ride_id, user_id, motorcycle_id),
  unique (diagnostic_session_id)
);

create index if not exists rides_user_status_started_idx
  on public.rides (user_id, status, started_at desc);

create index if not exists rides_motorcycle_completed_started_idx
  on public.rides (motorcycle_id, started_at desc)
  where status = 'completed';

create index if not exists rides_route_plan_id_idx
  on public.rides (route_plan_id)
  where route_plan_id is not null;

create table if not exists public.ride_points (
  ride_point_id bigint generated always as identity primary key,
  ride_id uuid not null,
  user_id uuid not null,
  motorcycle_id uuid not null,
  sequence_number integer not null,
  recorded_at timestamptz not null,
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  altitude_m numeric(9, 2),
  accuracy_m numeric(8, 2),
  bearing_degrees numeric(6, 2),
  gps_speed_kph numeric(7, 2),
  is_paused boolean not null default false,
  engine_rpm numeric(9, 2),
  ecu_speed_kph numeric(7, 2),
  coolant_temperature_c numeric(6, 2),
  fuel_level_percent numeric(6, 2),
  fuel_rate_lph numeric(8, 3),
  control_module_voltage numeric(6, 2),
  created_at timestamptz not null default now(),
  constraint ride_points_ride_owner_fk
    foreign key (ride_id, user_id, motorcycle_id)
    references public.rides (ride_id, user_id, motorcycle_id)
    on delete cascade,
  constraint ride_points_sequence_valid check (sequence_number >= 0),
  constraint ride_points_coordinates_valid check (
    latitude between -90 and 90 and longitude between -180 and 180
  ),
  constraint ride_points_metrics_valid check (
    (accuracy_m is null or accuracy_m between 0 and 10000)
    and (bearing_degrees is null or bearing_degrees between 0 and 360)
    and (gps_speed_kph is null or gps_speed_kph between 0 and 500)
    and (ecu_speed_kph is null or ecu_speed_kph between 0 and 500)
    and (engine_rpm is null or engine_rpm between 0 and 30000)
    and (fuel_level_percent is null or fuel_level_percent between 0 and 100)
    and (fuel_rate_lph is null or fuel_rate_lph between 0 and 1000)
  ),
  unique (ride_id, sequence_number)
);

create index if not exists ride_points_ride_recorded_idx
  on public.ride_points (ride_id, recorded_at, sequence_number);

create index if not exists ride_points_user_recorded_idx
  on public.ride_points (user_id, recorded_at desc);

create table if not exists public.ride_pauses (
  ride_pause_id bigint generated always as identity primary key,
  ride_id uuid not null,
  user_id uuid not null,
  motorcycle_id uuid not null,
  paused_at timestamptz not null,
  resumed_at timestamptz,
  reason text not null default 'manual',
  created_at timestamptz not null default now(),
  constraint ride_pauses_ride_owner_fk
    foreign key (ride_id, user_id, motorcycle_id)
    references public.rides (ride_id, user_id, motorcycle_id)
    on delete cascade,
  constraint ride_pauses_dates_valid check (
    resumed_at is null or resumed_at >= paused_at
  ),
  constraint ride_pauses_reason_valid check (
    reason in ('manual', 'app_recovery')
  )
);

create index if not exists ride_pauses_ride_paused_idx
  on public.ride_pauses (ride_id, paused_at);

alter table public.route_plans enable row level security;
alter table public.rides enable row level security;
alter table public.ride_points enable row level security;
alter table public.ride_pauses enable row level security;

revoke all on table public.route_plans from public, anon, authenticated;
revoke all on table public.rides from public, anon, authenticated;
revoke all on table public.ride_points from public, anon, authenticated;
revoke all on table public.ride_pauses from public, anon, authenticated;

grant select, insert, update, delete on table public.route_plans to authenticated;
grant select, insert, update, delete on table public.rides to authenticated;
grant select, insert, update, delete on table public.ride_points to authenticated;
grant select, insert, update, delete on table public.ride_pauses to authenticated;
grant usage, select on sequence public.ride_points_ride_point_id_seq
  to authenticated;
grant usage, select on sequence public.ride_pauses_ride_pause_id_seq
  to authenticated;

drop policy if exists "Users can read their own route plans"
  on public.route_plans;
drop policy if exists "Users can create their own route plans"
  on public.route_plans;
drop policy if exists "Users can update their own route plans"
  on public.route_plans;
drop policy if exists "Users can delete their own route plans"
  on public.route_plans;

create policy "Users can read their own route plans"
  on public.route_plans for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own route plans"
  on public.route_plans for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own route plans"
  on public.route_plans for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own route plans"
  on public.route_plans for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their own rides" on public.rides;
drop policy if exists "Users can create their own rides" on public.rides;
drop policy if exists "Users can update their own rides" on public.rides;
drop policy if exists "Users can delete their own rides" on public.rides;

create policy "Users can read their own rides"
  on public.rides for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own rides"
  on public.rides for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own rides"
  on public.rides for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own rides"
  on public.rides for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their own ride points"
  on public.ride_points;
drop policy if exists "Users can create their own ride points"
  on public.ride_points;
drop policy if exists "Users can update their own ride points"
  on public.ride_points;
drop policy if exists "Users can delete their own ride points"
  on public.ride_points;

create policy "Users can read their own ride points"
  on public.ride_points for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own ride points"
  on public.ride_points for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own ride points"
  on public.ride_points for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own ride points"
  on public.ride_points for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their own ride pauses"
  on public.ride_pauses;
drop policy if exists "Users can create their own ride pauses"
  on public.ride_pauses;
drop policy if exists "Users can update their own ride pauses"
  on public.ride_pauses;
drop policy if exists "Users can delete their own ride pauses"
  on public.ride_pauses;

create policy "Users can read their own ride pauses"
  on public.ride_pauses for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own ride pauses"
  on public.ride_pauses for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own ride pauses"
  on public.ride_pauses for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own ride pauses"
  on public.ride_pauses for delete to authenticated
  using ((select auth.uid()) = user_id);

drop trigger if exists route_plans_set_updated_at on public.route_plans;
create trigger route_plans_set_updated_at
before update on public.route_plans
for each row execute function private.set_profile_updated_at();

drop trigger if exists rides_set_updated_at on public.rides;
create trigger rides_set_updated_at
before update on public.rides
for each row execute function private.set_profile_updated_at();

drop function if exists public.get_motorcycle_usage_summary(uuid);
create function public.get_motorcycle_usage_summary(
  p_motorcycle_id uuid
)
returns table (
  recorded_ride_count bigint,
  total_distance_km numeric,
  total_fuel_consumed_liters numeric,
  estimated_fuel_consumed_liters numeric,
  rides_with_estimated_fuel bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with recorded_rides as (
    select
      ride.distance_km,
      ride.fuel_consumed_liters,
      ride.fuel_is_estimated
    from public.rides as ride
    where ride.motorcycle_id = p_motorcycle_id
      and ride.user_id = (select auth.uid())
      and ride.status = 'completed'

    union all

    select
      session.distance_km,
      session.fuel_consumed_liters,
      false as fuel_is_estimated
    from public.diagnostic_sessions as session
    where session.motorcycle_id = p_motorcycle_id
      and session.user_id = (select auth.uid())
      and session.session_type = 'ride'
      and session.ended_at is not null
      and not exists (
        select 1
        from public.rides as linked_ride
        where linked_ride.diagnostic_session_id = session.diagnostic_session_id
      )
  )
  select
    count(*) as recorded_ride_count,
    case when count(distance_km) = 0 then null else sum(distance_km) end,
    case
      when count(fuel_consumed_liters) = 0 then null
      else sum(fuel_consumed_liters)
    end,
    sum(fuel_consumed_liters) filter (where fuel_is_estimated),
    count(*) filter (
      where fuel_is_estimated and fuel_consumed_liters is not null
    )
  from recorded_rides;
$$;

revoke all on function public.get_motorcycle_usage_summary(uuid)
  from public, anon, authenticated;
grant execute on function public.get_motorcycle_usage_summary(uuid)
  to authenticated;

comment on table public.route_plans is
  'User-owned routed plans with provider-independent geometry and maneuvers.';
comment on table public.rides is
  'One real GPS ride, optionally linked to a saved route and ELM327 session.';
comment on table public.ride_points is
  'Ordered GPS samples with the closest available ELM327 readings.';
comment on column public.rides.fuel_is_estimated is
  'True when fuel is estimated from distance because PID 5E was unavailable.';
