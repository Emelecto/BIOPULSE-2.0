-- BioPulse 2.0 account-owned data. Original HealthKit samples remain on device.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_display_name_length check (
        display_name is null or char_length(btrim(display_name)) between 1 and 80
    )
);

create table public.user_settings (
    user_id uuid primary key references auth.users (id) on delete cascade,
    timezone_identifier text not null default 'UTC'
        check (char_length(timezone_identifier) between 1 and 64),
    unit_system text not null default 'metric'
        check (unit_system in ('metric', 'imperial')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Append-only record of cloud-sync consent. Raw HealthKit data is deliberately
-- not an allowed category; revocation is represented by a new event.
create table public.sync_consents (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    data_category text not null check (
        data_category in ('profile', 'settings', 'journal', 'derived_metrics')
    ),
    decision text not null check (decision in ('granted', 'revoked')),
    policy_version text not null check (char_length(btrim(policy_version)) between 1 and 40),
    recorded_at timestamptz not null default now()
);

create index sync_consents_user_category_recorded_idx
    on public.sync_consents (user_id, data_category, recorded_at desc);

create function private.stamp_sync_consent_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.recorded_at := pg_catalog.clock_timestamp();
    return new;
end;
$$;

create trigger sync_consents_stamp_recorded_at
    before insert on public.sync_consents
    for each row execute function private.stamp_sync_consent_event();

create table public.journal_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    category text not null check (category in ('habit', 'symptom', 'event')),
    title text not null check (
        char_length(btrim(title)) between 1 and 120
    ),
    notes text not null default '' check (char_length(notes) <= 2000),
    occurred_at timestamptz not null,
    timezone_identifier text not null check (
        char_length(timezone_identifier) between 1 and 64
    ),
    provenance text not null default 'user_entered'
        check (provenance in ('user_entered', 'imported_csv')),
    revision integer not null default 1 check (revision >= 1),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index journal_entries_owner_occurred_idx
    on public.journal_entries (user_id, occurred_at desc);

create function private.touch_account_record()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_table_name = 'profiles' then
        if new.id is distinct from old.id
           or new.created_at is distinct from old.created_at then
            raise exception 'immutable account record identity fields cannot change'
                using errcode = '23514';
        end if;
    elsif new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
        raise exception 'immutable account record identity fields cannot change'
            using errcode = '23514';
    end if;

    new.updated_at := pg_catalog.now();
    if tg_table_name = 'journal_entries' then
        new.revision := old.revision + 1;
    end if;
    return new;
end;
$$;

create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function private.touch_account_record();

create trigger user_settings_touch_updated_at
    before update on public.user_settings
    for each row execute function private.touch_account_record();

create trigger journal_entries_touch_revision
    before update on public.journal_entries
    for each row execute function private.touch_account_record();

-- The newest event determines whether the owner may upload that category.
-- This remains invoker-rights and is kept outside API-exposed schemas.
create function private.has_active_sync_consent(category text)
returns boolean
language sql
stable
set search_path = ''
as $$
    select coalesce((
        select consent.decision = 'granted'
        from public.sync_consents as consent
        where consent.user_id = (select auth.uid())
          and consent.data_category = category
        order by consent.id desc
        limit 1
    ), false);
$$;

revoke all on function private.touch_account_record() from public, anon, authenticated;
revoke all on function private.stamp_sync_consent_event() from public, anon, authenticated;
revoke all on function private.has_active_sync_consent(text) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.has_active_sync_consent(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.sync_consents enable row level security;
alter table public.journal_entries enable row level security;

-- Remove Supabase's commonly pre-granted API access, then allow only the
-- authenticated operations each table needs. There are no anon table grants.
revoke all on table public.profiles, public.user_settings,
    public.sync_consents, public.journal_entries
    from public, anon, authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update on table public.user_settings to authenticated;
grant select, insert on table public.sync_consents to authenticated;
grant select, insert, update, delete on table public.journal_entries to authenticated;
grant usage, select on sequence public.sync_consents_id_seq to authenticated;

create policy profiles_select_own
    on public.profiles for select to authenticated
    using ((select auth.uid()) is not null and id = (select auth.uid()));
create policy profiles_insert_own
    on public.profiles for insert to authenticated
    with check (
        (select auth.uid()) is not null
        and id = (select auth.uid())
        and (select private.has_active_sync_consent('profile'))
    );
create policy profiles_update_own
    on public.profiles for update to authenticated
    using ((select auth.uid()) is not null and id = (select auth.uid()))
    with check (
        (select auth.uid()) is not null
        and id = (select auth.uid())
        and (select private.has_active_sync_consent('profile'))
    );

create policy user_settings_select_own
    on public.user_settings for select to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy user_settings_insert_own
    on public.user_settings for insert to authenticated
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('settings'))
    );
create policy user_settings_update_own
    on public.user_settings for update to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()))
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('settings'))
    );

create policy sync_consents_select_own
    on public.sync_consents for select to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy sync_consents_insert_own
    on public.sync_consents for insert to authenticated
    with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy journal_entries_select_own
    on public.journal_entries for select to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy journal_entries_insert_own
    on public.journal_entries for insert to authenticated
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('journal'))
    );
create policy journal_entries_update_own
    on public.journal_entries for update to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()))
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('journal'))
    );
create policy journal_entries_delete_own
    on public.journal_entries for delete to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
