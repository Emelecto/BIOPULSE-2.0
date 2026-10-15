begin;
select plan(39);

select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'RLS enabled on profiles');
select ok((select relrowsecurity from pg_class where oid = 'public.user_settings'::regclass), 'RLS enabled on user_settings');
select ok((select relrowsecurity from pg_class where oid = 'public.sync_consents'::regclass), 'RLS enabled on sync_consents');
select ok((select relrowsecurity from pg_class where oid = 'public.journal_entries'::regclass), 'RLS enabled on journal_entries');
select ok((select relrowsecurity from pg_class where oid = 'public.coach_consents'::regclass), 'RLS enabled on coach consents');
select ok((select relrowsecurity from pg_class where oid = 'public.coach_memories'::regclass), 'RLS enabled on coach memories');

select ok(
    not has_table_privilege('anon', 'public.profiles', 'select')
    and not has_table_privilege('anon', 'public.profiles', 'insert')
    and not has_table_privilege('anon', 'public.profiles', 'update')
    and not has_table_privilege('anon', 'public.profiles', 'delete'),
    'anon has no profile table access'
);
select ok(
    not has_table_privilege('anon', 'public.user_settings', 'select')
    and not has_table_privilege('anon', 'public.user_settings', 'insert')
    and not has_table_privilege('anon', 'public.user_settings', 'update')
    and not has_table_privilege('anon', 'public.user_settings', 'delete'),
    'anon has no settings table access'
);
select ok(
    not has_table_privilege('anon', 'public.sync_consents', 'select')
    and not has_table_privilege('anon', 'public.sync_consents', 'insert')
    and not has_table_privilege('anon', 'public.sync_consents', 'update')
    and not has_table_privilege('anon', 'public.sync_consents', 'delete'),
    'anon has no consent table access'
);
select ok(
    not has_table_privilege('anon', 'public.journal_entries', 'select')
    and not has_table_privilege('anon', 'public.journal_entries', 'insert')
    and not has_table_privilege('anon', 'public.journal_entries', 'update')
    and not has_table_privilege('anon', 'public.journal_entries', 'delete'),
    'anon has no journal table access'
);
select ok(
    not has_table_privilege('anon', 'public.coach_consents', 'select')
    and not has_table_privilege('anon', 'public.coach_consents', 'insert')
    and not has_table_privilege('anon', 'public.coach_memories', 'select')
    and not has_table_privilege('authenticated', 'public.coach_memories', 'select')
    and not has_table_privilege('authenticated', 'public.coach_usage', 'select'),
    'coach memory and usage are server-only; anonymous users cannot record consent'
);
select ok(
    has_table_privilege('authenticated', 'public.coach_consents', 'select')
    and has_table_privilege('authenticated', 'public.coach_consents', 'insert')
    and not has_table_privilege('authenticated', 'public.coach_consents', 'update')
    and not has_table_privilege('authenticated', 'public.coach_consents', 'delete'),
    'authenticated users can append and inspect only immutable consent events'
);
select ok(
    not has_function_privilege('authenticated', 'public.consume_coach_request(uuid,integer)', 'execute')
    and has_function_privilege('service_role', 'public.consume_coach_request(uuid,integer)', 'execute'),
    'only the server role can consume the atomic Coach quota'
);

insert into auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data)
values
    ('00000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-user-a@biopulse.test', '', '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user-b@biopulse.test', '', '{}'::jsonb, '{}'::jsonb);

select is((select count(*) from public.profiles), 2::bigint, 'new Auth users receive profile rows');
select is((select count(*) from public.user_settings), 2::bigint, 'new Auth users receive settings rows');
select is((select timezone_identifier from public.user_settings where user_id = '00000000-0000-4000-8000-000000000001'), 'UTC', 'new account timezone has explicit default');
select is((select unit_system from public.user_settings where user_id = '00000000-0000-4000-8000-000000000002'), 'metric', 'new account units have explicit default');

insert into public.coach_consents (user_id, decision, policy_version)
values
    ('00000000-0000-4000-8000-000000000001', 'granted', 'coach-context-v1'),
    ('00000000-0000-4000-8000-000000000002', 'granted', 'coach-context-v1');

insert into public.journal_entries (id, user_id, category, title, occurred_at, timezone_identifier)
values
    ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'habit', 'A entry', now(), 'America/Bogota'),
    ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', 'habit', 'B entry', now(), 'America/Bogota');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is((select count(*) from public.profiles), 1::bigint, 'user A sees only their profile');
select is((select count(*) from public.user_settings), 1::bigint, 'user A sees only their settings');
select is((select count(*) from public.sync_consents), 0::bigint, 'user A sees no consent events before granting sync');
select is((select count(*) from public.journal_entries), 1::bigint, 'user A sees only their journal entries');
select is((select count(*) from public.coach_consents), 1::bigint, 'user A sees only their Coach consent event');
select throws_ok(
    $$insert into public.coach_consents (user_id, decision, policy_version)
      values ('00000000-0000-4000-8000-000000000002', 'granted', 'coach-context-v1')$$,
    '42501', null,
    'user A cannot grant Coach consent for user B'
);

select throws_ok(
    $$update public.profiles set display_name = 'Cloud A' where id = '00000000-0000-4000-8000-000000000001'$$,
    '42501', null,
    'profile upload is blocked before profile consent'
);
select throws_ok(
    $$update public.user_settings set unit_system = 'imperial' where user_id = '00000000-0000-4000-8000-000000000001'$$,
    '42501', null,
    'settings upload is blocked before settings consent'
);
select throws_ok(
    $$insert into public.journal_entries (user_id, category, title, occurred_at, timezone_identifier)
      values ('00000000-0000-4000-8000-000000000001', 'event', 'no consent', now(), 'America/Bogota')$$,
    '42501', null,
    'journal upload is blocked before journal consent'
);

insert into public.sync_consents (user_id, data_category, decision, policy_version)
values ('00000000-0000-4000-8000-000000000001', 'journal', 'granted', 'test-v1');
select lives_ok(
    $$insert into public.journal_entries (user_id, category, title, occurred_at, timezone_identifier)
      values ('00000000-0000-4000-8000-000000000001', 'event', 'consented', now(), 'America/Bogota')$$,
    'owner can upload journal data after granting consent'
);

update public.journal_entries set title = 'tampered'
where id = '10000000-0000-4000-8000-000000000002';
update public.journal_entries set title = 'A revised', revision = 99
where id = '10000000-0000-4000-8000-000000000001' and revision = 1;
select is(
    (select revision from public.journal_entries where id = '10000000-0000-4000-8000-000000000001'),
    2,
    'journal revision increments in database and ignores client revision'
);
select throws_ok(
    $$insert into public.journal_entries (user_id, category, title, occurred_at, timezone_identifier)
      values ('00000000-0000-4000-8000-000000000002', 'event', 'spoof', now(), 'America/Bogota')$$,
    '42501', null,
    'user A cannot insert data for user B'
);
select ok(not has_table_privilege(current_user, 'public.sync_consents', 'update'), 'consent events cannot be updated');
select ok(not has_table_privilege(current_user, 'public.sync_consents', 'delete'), 'consent events cannot be deleted');

insert into public.sync_consents (user_id, data_category, decision, policy_version)
values ('00000000-0000-4000-8000-000000000001', 'journal', 'revoked', 'test-v1');
select throws_ok(
    $$update public.journal_entries set title = 'after revoke'
      where id = '10000000-0000-4000-8000-000000000001' and revision = 2$$,
    '42501', null,
    'journal upload is blocked after consent is revoked'
);

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select is(
    (select title from public.journal_entries where id = '10000000-0000-4000-8000-000000000002'),
    'B entry',
    'user A cannot update user B journal entry and user B can see their own entry'
);
delete from public.journal_entries where id = '10000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select is(
    (select count(*) from public.journal_entries where id = '10000000-0000-4000-8000-000000000001'),
    1::bigint,
    'user B cannot delete user A journal entry'
);
delete from public.journal_entries where id = '10000000-0000-4000-8000-000000000001';
select is(
    (select count(*) from public.journal_entries where id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'owner can delete cloud journal data after revoking sync consent'
);

reset role;
set local role service_role;
select is(public.consume_coach_request('00000000-0000-4000-8000-000000000001', 2), true, 'first request is within the daily quota');
select is(public.consume_coach_request('00000000-0000-4000-8000-000000000001', 2), true, 'second request is within the daily quota');
select is(public.consume_coach_request('00000000-0000-4000-8000-000000000001', 2), false, 'request above the daily quota is blocked');
select is((select request_count from public.coach_usage where user_id = '00000000-0000-4000-8000-000000000001'), 3, 'quota counting is atomic and records rejected over-limit requests');

select * from finish();
rollback;
