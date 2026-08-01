-- User-owned motorcycles and ELM327 diagnostic history for MotoMap.
-- Bluetooth identifiers are saved per motorcycle so the selected primary
-- motorcycle can reconnect to its adapter on future app sessions.

create table public.motorcycles (
  motorcycle_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  nickname text,
  make text not null,
  model text not null,
  model_year smallint not null,
  motorcycle_type text not null,
  engine_displacement_cc integer,
  is_primary boolean not null default false,
  elm_device_name text,
  elm_device_identifier text,
  elm_transport text,
  elm_auto_connect boolean not null default true,
  last_elm_connected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint motorcycles_nickname_valid check (
    nickname is null or char_length(btrim(nickname)) between 1 and 60
  ),
  constraint motorcycles_make_valid check (
    char_length(btrim(make)) between 1 and 80
  ),
  constraint motorcycles_model_valid check (
    char_length(btrim(model)) between 1 and 80
  ),
  constraint motorcycles_model_year_valid check (
    model_year between 1900 and 2100
  ),
  constraint motorcycles_type_valid check (
    motorcycle_type in (
      'adventure',
      'cruiser',
      'dual_sport',
      'scooter',
      'sport',
      'standard',
      'touring',
      'other'
    )
  ),
  constraint motorcycles_engine_displacement_valid check (
    engine_displacement_cc is null
    or engine_displacement_cc between 25 and 5000
  ),
  constraint motorcycles_elm_transport_valid check (
    elm_transport is null or elm_transport in ('bluetooth_classic', 'ble', 'wifi')
  ),
  constraint motorcycles_elm_pairing_complete check (
    (elm_device_identifier is null and elm_transport is null)
    or (elm_device_identifier is not null and elm_transport is not null)
  ),
  unique (motorcycle_id, user_id)
);

create index motorcycles_user_id_idx
  on public.motorcycles (user_id, created_at desc);

create unique index motorcycles_one_primary_per_user_idx
  on public.motorcycles (user_id)
  where is_primary;

create table public.diagnostic_sessions (
  diagnostic_session_id uuid primary key default gen_random_uuid(),
  motorcycle_id uuid not null,
  user_id uuid not null,
  session_type text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  elm_device_name text,
  elm_device_identifier text,
  elm_version text,
  detected_protocol text,
  adapter_voltage numeric(5, 2),
  supported_pids text[] not null default '{}',
  health_score smallint,
  score_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint diagnostic_sessions_motorcycle_owner_fk
    foreign key (motorcycle_id, user_id)
    references public.motorcycles (motorcycle_id, user_id)
    on delete cascade,
  constraint diagnostic_sessions_type_valid check (
    session_type in ('pre_ride', 'ride', 'post_ride', 'manual')
  ),
  constraint diagnostic_sessions_dates_valid check (
    ended_at is null or ended_at >= started_at
  ),
  constraint diagnostic_sessions_voltage_valid check (
    adapter_voltage is null or adapter_voltage between 0 and 60
  ),
  constraint diagnostic_sessions_health_score_valid check (
    health_score is null or health_score between 0 and 100
  ),
  unique (diagnostic_session_id, motorcycle_id, user_id)
);

create index diagnostic_sessions_motorcycle_started_idx
  on public.diagnostic_sessions (motorcycle_id, started_at desc);

create index diagnostic_sessions_user_started_idx
  on public.diagnostic_sessions (user_id, started_at desc);

create table public.diagnostic_samples (
  diagnostic_sample_id bigint generated always as identity primary key,
  diagnostic_session_id uuid not null,
  motorcycle_id uuid not null,
  user_id uuid not null,
  recorded_at timestamptz not null default now(),
  engine_rpm numeric(9, 2),
  vehicle_speed_kph numeric(7, 2),
  coolant_temperature_c numeric(6, 2),
  intake_air_temperature_c numeric(6, 2),
  throttle_position_percent numeric(6, 2),
  engine_load_percent numeric(6, 2),
  fuel_level_percent numeric(6, 2),
  control_module_voltage numeric(6, 2),
  distance_with_mil_km numeric(10, 2),
  runtime_since_engine_start_seconds integer,
  extra_pids jsonb not null default '{}'::jsonb,
  constraint diagnostic_samples_session_owner_fk
    foreign key (diagnostic_session_id, motorcycle_id, user_id)
    references public.diagnostic_sessions (
      diagnostic_session_id,
      motorcycle_id,
      user_id
    )
    on delete cascade,
  constraint diagnostic_samples_rpm_valid check (
    engine_rpm is null or engine_rpm between 0 and 30000
  ),
  constraint diagnostic_samples_speed_valid check (
    vehicle_speed_kph is null or vehicle_speed_kph between 0 and 500
  ),
  constraint diagnostic_samples_percentages_valid check (
    (throttle_position_percent is null or throttle_position_percent between 0 and 100)
    and (engine_load_percent is null or engine_load_percent between 0 and 100)
    and (fuel_level_percent is null or fuel_level_percent between 0 and 100)
  )
);

create index diagnostic_samples_session_recorded_idx
  on public.diagnostic_samples (diagnostic_session_id, recorded_at);

create table public.diagnostic_trouble_codes (
  diagnostic_trouble_code_id bigint generated always as identity primary key,
  diagnostic_session_id uuid not null,
  motorcycle_id uuid not null,
  user_id uuid not null,
  code text not null,
  status text not null default 'active',
  description text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  cleared_at timestamptz,
  raw_response text,
  constraint diagnostic_trouble_codes_session_owner_fk
    foreign key (diagnostic_session_id, motorcycle_id, user_id)
    references public.diagnostic_sessions (
      diagnostic_session_id,
      motorcycle_id,
      user_id
    )
    on delete cascade,
  constraint diagnostic_trouble_codes_code_valid check (
    code ~ '^[PBCU][0-3][0-9A-F]{3}$'
  ),
  constraint diagnostic_trouble_codes_status_valid check (
    status in ('active', 'pending', 'permanent', 'cleared')
  ),
  constraint diagnostic_trouble_codes_dates_valid check (
    last_seen_at >= first_seen_at
    and (cleared_at is null or cleared_at >= first_seen_at)
  ),
  unique (diagnostic_session_id, code, status)
);

create index diagnostic_trouble_codes_motorcycle_seen_idx
  on public.diagnostic_trouble_codes (motorcycle_id, last_seen_at desc);

alter table public.motorcycles enable row level security;
alter table public.diagnostic_sessions enable row level security;
alter table public.diagnostic_samples enable row level security;
alter table public.diagnostic_trouble_codes enable row level security;

revoke all on table public.motorcycles from public, anon, authenticated;
revoke all on table public.diagnostic_sessions from public, anon, authenticated;
revoke all on table public.diagnostic_samples from public, anon, authenticated;
revoke all on table public.diagnostic_trouble_codes from public, anon, authenticated;

grant select, insert, update, delete on table public.motorcycles to authenticated;
grant select, insert, update, delete on table public.diagnostic_sessions to authenticated;
grant select, insert, update, delete on table public.diagnostic_samples to authenticated;
grant select, insert, update, delete on table public.diagnostic_trouble_codes to authenticated;
grant usage, select on sequence public.diagnostic_samples_diagnostic_sample_id_seq
  to authenticated;
grant usage, select on sequence
  public.diagnostic_trouble_codes_diagnostic_trouble_code_id_seq
  to authenticated;

create policy "Users can read their own motorcycles"
  on public.motorcycles for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own motorcycles"
  on public.motorcycles for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own motorcycles"
  on public.motorcycles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own motorcycles"
  on public.motorcycles for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their own diagnostic sessions"
  on public.diagnostic_sessions for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own diagnostic sessions"
  on public.diagnostic_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own diagnostic sessions"
  on public.diagnostic_sessions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own diagnostic sessions"
  on public.diagnostic_sessions for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their own diagnostic samples"
  on public.diagnostic_samples for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own diagnostic samples"
  on public.diagnostic_samples for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own diagnostic samples"
  on public.diagnostic_samples for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own diagnostic samples"
  on public.diagnostic_samples for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their own trouble codes"
  on public.diagnostic_trouble_codes for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add their own trouble codes"
  on public.diagnostic_trouble_codes for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own trouble codes"
  on public.diagnostic_trouble_codes for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own trouble codes"
  on public.diagnostic_trouble_codes for delete to authenticated
  using ((select auth.uid()) = user_id);

create trigger motorcycles_set_updated_at
before update on public.motorcycles
for each row execute function private.set_profile_updated_at();

create or replace function public.set_primary_motorcycle(
  p_motorcycle_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.motorcycles
    where motorcycle_id = p_motorcycle_id
      and user_id = (select auth.uid())
  ) then
    raise exception using
      errcode = '42501',
      message = 'Motorcycle is not owned by the authenticated user';
  end if;

  update public.motorcycles
  set is_primary = (motorcycle_id = p_motorcycle_id)
  where user_id = (select auth.uid());
end;
$$;

revoke all on function public.set_primary_motorcycle(uuid)
  from public, anon, authenticated;
grant execute on function public.set_primary_motorcycle(uuid)
  to authenticated;
