begin;
select plan(22);

select ok((select relrowsecurity from pg_class where oid = 'public.daily_metric_summaries'::regclass), 'daily aggregates have RLS');
select ok(
    not has_table_privilege('anon', 'public.daily_metric_summaries', 'select')
    and not has_table_privilege('anon', 'public.daily_metric_summaries', 'insert'),
    'anonymous clients cannot access aggregates'
);
select ok(
    has_table_privilege('authenticated', 'public.daily_metric_summaries', 'select')
    and has_table_privilege('authenticated', 'public.daily_metric_summaries', 'delete'),
    'signed-in owners have read and deletion rights'
);
select ok(
    not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'daily_metric_summaries'
          and column_name in ('raw_payload', 'sample_timestamp', 'device_id')
    ),
    'schema contains no original sample payload or device identifier'
);

insert into auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data)
values
    ('00000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated', 'metric-a@biopulse.test', '', '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated', 'metric-b@biopulse.test', '', '{}'::jsonb, '{}'::jsonb);

insert into public.daily_metric_summaries
    (id, user_id, local_date, timezone_identifier, metric_kind, value, unit,
     aggregation, sample_count, coverage_fraction, quality, source_kind, formula_version)
values
    ('20000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000012',
     '2026-10-15', 'America/Bogota', 'hrv_sdnn', 42, 'ms', 'latest', 1, null,
     'observed', 'healthkit_aggregate', 'healthkit-daily-v1');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is((select count(*) from public.daily_metric_summaries), 0::bigint, 'user A cannot read B aggregate');
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-15',
              'America/Bogota', 'hrv_sdnn', 45, 'ms', 'latest', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '42501', null, 'upload is denied before biometric consent'
);

insert into public.sync_consents (user_id, data_category, decision, policy_version)
values ('00000000-0000-4000-8000-000000000011', 'derived_metrics', 'granted', 'sync-v1');

select lives_ok(
    $$insert into public.daily_metric_summaries
        (id, user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, coverage_fraction, quality, source_kind, formula_version)
      values ('20000000-0000-4000-8000-000000000011',
              '00000000-0000-4000-8000-000000000011', '2026-10-15',
              'America/Bogota', 'hrv_sdnn', 45, 'ms', 'latest', 1, null,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    'owner may upload an aggregate after consent'
);
select is((select count(*) from public.daily_metric_summaries), 1::bigint, 'owner sees only their aggregate');

update public.daily_metric_summaries set value = 46, revision = 99
where id = '20000000-0000-4000-8000-000000000011' and revision = 1;
select is(
    (select revision from public.daily_metric_summaries
     where id = '20000000-0000-4000-8000-000000000011'),
    2, 'server controls optimistic revision'
);
select throws_ok(
    $$update public.daily_metric_summaries
      set user_id = '00000000-0000-4000-8000-000000000012'
      where id = '20000000-0000-4000-8000-000000000011'$$,
    '23514', null, 'aggregate owner cannot be changed'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000012', '2026-10-15',
              'America/Bogota', 'steps', 100, 'count', 'sum', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '42501', null, 'owner spoofing is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'steps', 100, 'bpm', 'sum', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23514', null, 'wrong canonical unit is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'steps', 'NaN'::float8, 'count', 'sum', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23514', null, 'nonfinite aggregate is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'steps', -10, 'count', 'sum', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23514', null, 'negative steps are denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'oxygen_saturation', 97, 'fraction', 'mean', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23514', null, 'percent-vs-fraction oxygen mistake is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'steps', 100, 'count', 'sum', 0,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23514', null, 'zero-source aggregate is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-15',
              'America/Bogota', 'hrv_sdnn', 44, 'ms', 'latest', 1,
              'observed', 'healthkit_aggregate', 'healthkit-daily-v1')$$,
    '23505', null, 'duplicate owner-day-metric-source is denied'
);
select throws_ok(
    $$insert into public.daily_metric_summaries
        (user_id, local_date, timezone_identifier, metric_kind, value, unit,
         aggregation, sample_count, quality, source_kind, formula_version)
      values ('00000000-0000-4000-8000-000000000011', '2026-10-14',
              'America/Bogota', 'hrv_sdnn', 44, 'ms', 'latest', 1,
              'observed', 'healthkit_raw', 'healthkit-daily-v1')$$,
    '23514', null, 'raw HealthKit sources cannot be labeled as cloud aggregates'
);
select is(
    (select count(*) from public.daily_metric_summaries
     where id = '20000000-0000-4000-8000-000000000012'),
    0::bigint, 'B aggregate remains invisible after attempted spoofing'
);

insert into public.sync_consents (user_id, data_category, decision, policy_version)
values ('00000000-0000-4000-8000-000000000011', 'derived_metrics', 'revoked', 'sync-v1');
select throws_ok(
    $$update public.daily_metric_summaries set value = 47
      where id = '20000000-0000-4000-8000-000000000011' and revision = 2$$,
    '42501', null, 'revocation prevents further uploads'
);
delete from public.daily_metric_summaries
where id = '20000000-0000-4000-8000-000000000011';
select is((select count(*) from public.daily_metric_summaries), 0::bigint,
    'owner can erase an aggregate after revocation');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000012', true);
select is((select count(*) from public.daily_metric_summaries), 1::bigint,
    'B aggregate remains intact');

select * from finish();
rollback;
