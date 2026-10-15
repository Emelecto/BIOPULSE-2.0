-- Aggregate operational counts only. No journal, biometric, profile content or identities.
create function public.admin_operational_metrics()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'accounts', (select count(*) from auth.users),
    'newAccounts7d', (select count(*) from auth.users where created_at >= pg_catalog.now() - interval '7 days'),
    'coachRequestsToday', (select coalesce(sum(request_count), 0) from public.coach_usage
      where window_start = pg_catalog.date_trunc('day', pg_catalog.now() at time zone 'UTC') at time zone 'UTC'),
    'coachUsersToday', (select count(*) from public.coach_usage
      where window_start = pg_catalog.date_trunc('day', pg_catalog.now() at time zone 'UTC') at time zone 'UTC'),
    'syncConsentEvents7d', (select count(*) from public.sync_consents
      where recorded_at >= pg_catalog.now() - interval '7 days'),
    'coachConsentEvents7d', (select count(*) from public.coach_consents
      where recorded_at >= pg_catalog.now() - interval '7 days'),
    'generatedAt', pg_catalog.now()
  );
$$;

revoke all on function public.admin_operational_metrics() from public, anon, authenticated;
grant execute on function public.admin_operational_metrics() to service_role;
