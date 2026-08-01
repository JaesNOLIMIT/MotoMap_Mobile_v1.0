-- Catalog references make motorcycle entry faster without making MotoMap
-- dependent on catalog availability. Ride summary columns preserve real ELM327
-- readings at the end of each session so history and lifetime totals do not
-- require scanning every five-second diagnostic sample.

alter table public.motorcycles
  add column if not exists catalog_source text,
  add column if not exists catalog_make_id integer,
  add column if not exists catalog_model_id integer;

alter table public.diagnostic_samples
  add column if not exists fuel_rate_lph numeric(8, 3);

alter table public.diagnostic_sessions
  add column if not exists distance_km numeric(12, 3),
  add column if not exists fuel_consumed_liters numeric(10, 4),
  add column if not exists average_speed_kph numeric(7, 2),
  add column if not exists maximum_speed_kph numeric(7, 2),
  add column if not exists average_engine_rpm numeric(9, 2),
  add column if not exists maximum_engine_rpm numeric(9, 2),
  add column if not exists maximum_coolant_temperature_c numeric(6, 2),
  add column if not exists minimum_control_module_voltage numeric(6, 2),
  add column if not exists ending_fuel_level_percent numeric(6, 2),
  add column if not exists sample_count integer not null default 0,
  add column if not exists trouble_code_count smallint not null default 0,
  add column if not exists trouble_codes text[] not null default '{}';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'motorcycles_catalog_source_valid'
      and conrelid = 'public.motorcycles'::regclass
  ) then
    alter table public.motorcycles
      add constraint motorcycles_catalog_source_valid check (
        catalog_source is null or catalog_source = 'nhtsa_vpic'
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'diagnostic_samples_fuel_rate_valid'
      and conrelid = 'public.diagnostic_samples'::regclass
  ) then
    alter table public.diagnostic_samples
      add constraint diagnostic_samples_fuel_rate_valid check (
        fuel_rate_lph is null or fuel_rate_lph between 0 and 1000
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'diagnostic_sessions_ride_summary_valid'
      and conrelid = 'public.diagnostic_sessions'::regclass
  ) then
    alter table public.diagnostic_sessions
      add constraint diagnostic_sessions_ride_summary_valid check (
        (distance_km is null or distance_km between 0 and 1000000)
        and (
          fuel_consumed_liters is null
          or fuel_consumed_liters between 0 and 100000
        )
        and (average_speed_kph is null or average_speed_kph between 0 and 500)
        and (maximum_speed_kph is null or maximum_speed_kph between 0 and 500)
        and (average_engine_rpm is null or average_engine_rpm between 0 and 30000)
        and (maximum_engine_rpm is null or maximum_engine_rpm between 0 and 30000)
        and (
          ending_fuel_level_percent is null
          or ending_fuel_level_percent between 0 and 100
        )
        and sample_count >= 0
        and trouble_code_count >= 0
      );
  end if;
end;
$$;

create index if not exists diagnostic_sessions_motorcycle_type_started_idx
  on public.diagnostic_sessions (
    motorcycle_id,
    session_type,
    started_at desc,
    diagnostic_session_id desc
  );

comment on column public.diagnostic_sessions.distance_km is
  'Distance integrated from real ECU vehicle-speed samples; null when unavailable.';
comment on column public.diagnostic_sessions.fuel_consumed_liters is
  'Fuel integrated from OBD Mode 01 PID 5E fuel-rate samples; null when unsupported.';

create or replace function public.get_motorcycle_usage_summary(
  p_motorcycle_id uuid
)
returns table (
  recorded_ride_count bigint,
  total_distance_km numeric,
  total_fuel_consumed_liters numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    count(*) as recorded_ride_count,
    case
      when count(session.distance_km) = 0 then null
      else sum(session.distance_km)
    end as total_distance_km,
    case
      when count(session.fuel_consumed_liters) = 0 then null
      else sum(session.fuel_consumed_liters)
    end as total_fuel_consumed_liters
  from public.diagnostic_sessions as session
  where session.motorcycle_id = p_motorcycle_id
    and session.user_id = (select auth.uid())
    and session.session_type = 'ride'
    and session.ended_at is not null;
$$;

revoke all on function public.get_motorcycle_usage_summary(uuid)
  from public, anon, authenticated;
grant execute on function public.get_motorcycle_usage_summary(uuid)
  to authenticated;
