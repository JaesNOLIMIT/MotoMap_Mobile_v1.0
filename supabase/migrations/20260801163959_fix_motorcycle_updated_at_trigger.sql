-- Motorcycles previously reused the profile trigger, which validates
-- NEW.birth_date. Motorcycle rows do not have that column, so any update
-- (including photo and ELM327 changes) failed with PostgreSQL error 42703.

create or replace function private.set_motorcycle_updated_at()
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

revoke all on function private.set_motorcycle_updated_at()
  from public, anon, authenticated;

drop trigger if exists motorcycles_set_updated_at
  on public.motorcycles;

create trigger motorcycles_set_updated_at
before update on public.motorcycles
for each row execute function private.set_motorcycle_updated_at();
