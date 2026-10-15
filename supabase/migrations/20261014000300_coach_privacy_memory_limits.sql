-- Coach consent is separate from cloud-sync consent. This event explicitly
-- authorizes sending derived health context and selected journal context to
-- the configured AI provider; raw HealthKit samples are not part of the API.
create table public.coach_consents (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    decision text not null check (decision in ('granted', 'revoked')),
    policy_version text not null check (char_length(btrim(policy_version)) between 1 and 40),
    recorded_at timestamptz not null default now()
);

create index coach_consents_owner_recorded_idx
    on public.coach_consents (user_id, id desc);

create function private.stamp_coach_consent_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.recorded_at := pg_catalog.clock_timestamp();
    return new;
end;
$$;

create trigger coach_consents_stamp_recorded
    before insert on public.coach_consents
    for each row execute function private.stamp_coach_consent_event();

alter table public.coach_consents enable row level security;
revoke all on table public.coach_consents from public, anon, authenticated;
grant select, insert on table public.coach_consents to authenticated;
grant usage, select on sequence public.coach_consents_id_seq to authenticated;

create policy coach_consents_select_own
    on public.coach_consents for select to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy coach_consents_insert_own
    on public.coach_consents for insert to authenticated
    with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create table public.coach_memories (
    user_id uuid primary key references auth.users (id) on delete cascade,
    summary text not null check (char_length(summary) <= 4000),
    updated_at timestamptz not null default now(),
    expires_at timestamptz not null,
    constraint coach_memories_expiry_after_update check (expires_at > updated_at)
);

-- Memories and quota counters are server-only; users cannot read a hidden
-- transcript or bypass the Edge Function's expiry and rate checks.
alter table public.coach_memories enable row level security;
revoke all on table public.coach_memories from public, anon, authenticated;
grant select, insert, update, delete on table public.coach_memories to service_role;

create table public.coach_usage (
    user_id uuid primary key references auth.users (id) on delete cascade,
    window_start timestamptz not null,
    request_count integer not null check (request_count >= 1)
);

alter table public.coach_usage enable row level security;
revoke all on table public.coach_usage from public, anon, authenticated;
grant select, insert, update, delete on table public.coach_usage to service_role;

-- Physically remove expired summaries hourly, allowing up to one hour of
-- cleanup delay after the seven-day expiry timestamp.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule(
    'biopulse-purge-expired-coach-memory',
    '10 * * * *',
    'delete from public.coach_memories where expires_at <= now()'
);

create function public.consume_coach_request(p_user_id uuid, p_daily_limit integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    allowed boolean;
    utc_day timestamptz := pg_catalog.date_trunc(
        'day', pg_catalog.now() at time zone 'UTC'
    ) at time zone 'UTC';
begin
    if p_user_id is null or p_daily_limit is null or p_daily_limit < 1 or p_daily_limit > 100 then
        raise exception 'invalid coach quota arguments' using errcode = '22023';
    end if;

    insert into public.coach_usage (user_id, window_start, request_count)
    values (p_user_id, utc_day, 1)
    on conflict (user_id) do update
       set window_start = excluded.window_start,
           request_count = case
               when public.coach_usage.window_start = excluded.window_start
                   then public.coach_usage.request_count + 1
               else 1
           end
    returning request_count <= p_daily_limit into allowed;

    return allowed;
end;
$$;

revoke all on function public.consume_coach_request(uuid, integer)
    from public, anon, authenticated;
grant execute on function public.consume_coach_request(uuid, integer) to service_role;
