begin;
select plan(13);

select ok((select relrowsecurity from pg_class where oid = 'public.health_bridge_connections'::regclass), 'bridge secrets have RLS');
select ok(not has_table_privilege('anon', 'public.health_bridge_connections', 'select'), 'anon cannot read bridge secret hashes');
select ok(not has_table_privilege('authenticated', 'public.health_bridge_connections', 'select'), 'account clients cannot read bridge secret hashes');
select ok((select relrowsecurity from pg_class where oid = 'public.intraday_metric_summaries'::regclass), 'hourly aggregates have RLS');
select ok(not has_table_privilege('anon', 'public.intraday_metric_summaries', 'select'), 'anon cannot read hourly data');
select ok(not has_table_privilege('authenticated', 'public.intraday_metric_summaries', 'insert'), 'account clients cannot forge bridge hourly data');
select ok((select relrowsecurity from pg_class where oid = 'public.sleep_stage_summaries'::regclass), 'sleep stage aggregates have RLS');
select ok(not has_table_privilege('anon', 'public.sleep_stage_summaries', 'select'), 'anon cannot read sleep stages');
select ok(not has_table_privilege('authenticated', 'public.sleep_stage_summaries', 'insert'), 'account clients cannot forge bridge sleep stages');
select ok(not exists (
  select 1 from information_schema.columns
  where table_schema = 'public' and table_name in ('intraday_metric_summaries', 'sleep_stage_summaries')
  and column_name in ('raw_payload', 'sample_timestamp', 'device_id')
), 'new tables contain no original sample fields');

insert into auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000031', 'authenticated', 'authenticated', 'bridge-a@biopulse.test', '', '{}'::jsonb, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000000032', 'authenticated', 'authenticated', 'bridge-b@biopulse.test', '', '{}'::jsonb, '{}'::jsonb);
insert into public.intraday_metric_summaries (user_id, bucket_start, local_date, timezone_identifier, metric_kind, value, unit, aggregation)
values ('00000000-0000-4000-8000-000000000032', '2026-10-15T13:00:00Z', '2026-10-15', 'UTC-05:00', 'active_energy', 42, 'kcal', 'sum');
insert into public.sleep_stage_summaries (user_id, local_date, stage, minutes)
values ('00000000-0000-4000-8000-000000000032', '2026-10-15', 'deep', 80);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000031', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is((select count(*) from public.intraday_metric_summaries), 0::bigint, 'account A cannot read B hourly aggregates');
select is((select count(*) from public.sleep_stage_summaries), 0::bigint, 'account A cannot read B sleep stages');
insert into public.sync_consents (user_id, data_category, decision, policy_version)
values ('00000000-0000-4000-8000-000000000031', 'derived_metrics', 'granted', 'hae-aggregate-v1');
select throws_ok(
  $$insert into public.daily_metric_summaries
      (user_id, local_date, timezone_identifier, metric_kind, value, unit,
       aggregation, sample_count, quality, source_kind, formula_version)
    values ('00000000-0000-4000-8000-000000000031', '2026-10-15', 'UTC-05:00',
      'steps', 9000, 'count', 'sum', 1, 'observed', 'health_auto_export_aggregate', 'hae-v2-aggregate-v1')$$,
  '42501', null, 'account client cannot forge bridge provenance even with daily consent'
);

select * from finish();
rollback;
