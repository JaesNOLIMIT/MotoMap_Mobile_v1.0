-- Keep "last connected motorcycle" ordering independent of a phone's clock.
-- The client still signals a successful connection by changing the column,
-- while Postgres records the authoritative time.

create or replace function public.set_elm_connection_server_time()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.last_elm_connected_at is not null
     and new.last_elm_connected_at is distinct from old.last_elm_connected_at
  then
    new.last_elm_connected_at := clock_timestamp();
  end if;
  return new;
end;
$$;

revoke all on function public.set_elm_connection_server_time() from public;
revoke all on function public.set_elm_connection_server_time() from anon;
revoke all on function public.set_elm_connection_server_time() from authenticated;

drop trigger if exists motorcycles_set_elm_connection_server_time
on public.motorcycles;

create trigger motorcycles_set_elm_connection_server_time
before update of last_elm_connected_at on public.motorcycles
for each row
execute function public.set_elm_connection_server_time();
