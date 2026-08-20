-- Evaluate leader ownership without nesting shared_rides RLS inside the
-- shared_ride_members INSERT policy.

create or replace function private.is_shared_ride_leader(p_shared_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shared_rides ride
    where ride.shared_ride_id = p_shared_ride_id
      and ride.leader_id = (select auth.uid())
  );
$$;

revoke all on function private.is_shared_ride_leader(uuid)
  from public, anon, authenticated;
grant execute on function private.is_shared_ride_leader(uuid) to authenticated;

drop policy if exists "Leaders can add themselves"
  on public.shared_ride_members;
create policy "Leaders can add themselves"
on public.shared_ride_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'leader'
  and private.is_shared_ride_leader(shared_ride_id)
);
