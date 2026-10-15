-- Daily aggregates only. Raw HealthKit samples and device identifiers remain local.
create table public.daily_metric_summaries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    local_date date not null,
    timezone_identifier text not null
        check (char_length(timezone_identifier) between 1 and 64),
    metric_kind text not null check (metric_kind in (
        'heart_rate', 'resting_heart_rate', 'hrv_sdnn',
        'respiratory_rate', 'oxygen_saturation', 'sleep_duration',
        'steps', 'active_energy', 'exercise_duration', 'vo2_max',
        'wrist_temperature_deviation'
    )),
    value double precision not null
        check (value > '-Infinity'::double precision and value < 'Infinity'::double precision),
    unit text not null,
    aggregation text not null check (aggregation in (
        'mean', 'median', 'sum', 'duration', 'latest'
    )),
    sample_count integer not null check (sample_count between 1 and 1000000),
    coverage_fraction double precision
        check (coverage_fraction between 0 and 1),
    quality text not null check (quality in ('observed', 'partial', 'estimated')),
    source_kind text not null check (source_kind in ('healthkit_aggregate', 'csv_aggregate')),
    formula_version text not null check (char_length(btrim(formula_version)) between 1 and 40),
    revision integer not null default 1 check (revision >= 1),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, local_date, metric_kind, source_kind),
    constraint metric_unit_matches_kind check (
        (metric_kind in ('heart_rate', 'resting_heart_rate') and unit = 'bpm') or
        (metric_kind = 'hrv_sdnn' and unit = 'ms') or
        (metric_kind = 'respiratory_rate' and unit = 'breaths/min') or
        (metric_kind = 'oxygen_saturation' and unit = 'fraction') or
        (metric_kind in ('sleep_duration', 'exercise_duration') and unit = 'min') or
        (metric_kind = 'steps' and unit = 'count') or
        (metric_kind = 'active_energy' and unit = 'kcal') or
        (metric_kind = 'vo2_max' and unit = 'mL/kg/min') or
        (metric_kind = 'wrist_temperature_deviation' and unit = 'degC')
    )
);

create index daily_metric_summaries_owner_date_idx
    on public.daily_metric_summaries (user_id, local_date desc);

create function private.touch_daily_metric_summary()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
        raise exception 'immutable daily metric identity fields cannot change'
            using errcode = '23514';
    end if;
    new.updated_at := pg_catalog.now();
    new.revision := old.revision + 1;
    return new;
end;
$$;

revoke all on function private.touch_daily_metric_summary() from public, anon, authenticated;
create trigger daily_metric_summaries_touch_revision
    before update on public.daily_metric_summaries
    for each row execute function private.touch_daily_metric_summary();

alter table public.daily_metric_summaries enable row level security;
revoke all on table public.daily_metric_summaries from public, anon, authenticated;
grant select, insert, update, delete on table public.daily_metric_summaries to authenticated;

create policy daily_metric_summaries_select_own
    on public.daily_metric_summaries for select to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy daily_metric_summaries_insert_own
    on public.daily_metric_summaries for insert to authenticated
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('derived_metrics'))
    );
create policy daily_metric_summaries_update_own
    on public.daily_metric_summaries for update to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()))
    with check (
        (select auth.uid()) is not null
        and user_id = (select auth.uid())
        and (select private.has_active_sync_consent('derived_metrics'))
    );
create policy daily_metric_summaries_delete_own
    on public.daily_metric_summaries for delete to authenticated
    using ((select auth.uid()) is not null and user_id = (select auth.uid()));
