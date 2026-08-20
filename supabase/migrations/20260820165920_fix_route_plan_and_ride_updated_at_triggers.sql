-- Route plans and completed rides previously reused the profile-only trigger.
-- That trigger validates NEW.birth_date, a column these tables do not have,
-- so updating a planned route failed with PostgreSQL error 42703.

create or replace function private.set_record_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.set_record_updated_at()
  from public, anon, authenticated;

drop trigger if exists route_plans_set_updated_at on public.route_plans;
create trigger route_plans_set_updated_at
before update on public.route_plans
for each row execute function private.set_record_updated_at();

drop trigger if exists rides_set_updated_at on public.rides;
create trigger rides_set_updated_at
before update on public.rides
for each row execute function private.set_record_updated_at();
