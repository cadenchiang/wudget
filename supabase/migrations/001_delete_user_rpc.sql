-- Self-service account deletion (App Store guideline 5.1.1(v)).
-- Called by the app via supabase.rpc("delete_user") from AccountStore.deleteAccount().
--
-- SECURITY DEFINER lets the authenticated role delete its own auth.users row;
-- the auth.uid() predicate guarantees a user can only ever delete themselves.
-- Execution is revoked from anon/public and granted only to authenticated.
create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke execute on function public.delete_user() from anon, public;
grant execute on function public.delete_user() to authenticated;
