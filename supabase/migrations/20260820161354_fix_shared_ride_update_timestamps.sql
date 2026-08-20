-- shared_rides and shared_ride_members do not have profile birth-date fields,
-- so they need a generic server-time updated_at trigger.

create or replace function private.set_shared_ride_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function private.set_shared_ride_updated_at()
  from public, anon, authenticated;

drop trigger if exists shared_rides_set_updated_at on public.shared_rides;
create trigger shared_rides_set_updated_at
before update on public.shared_rides
for each row execute function private.set_shared_ride_updated_at();

drop trigger if exists shared_ride_members_set_updated_at
  on public.shared_ride_members;
create trigger shared_ride_members_set_updated_at
before update on public.shared_ride_members
for each row execute function private.set_shared_ride_updated_at();
