-- Health Auto Export sends aggregates only. The bridge secret is never exposed through PostgREST.
alter table public.sync_consents drop constraint sync_consents_data_category_check;
alter table public.sync_consents add constraint sync_consents_data_category_check
  check (data_category in ('profile', 'settings', 'journal', 'derived_metrics', 'intraday_metrics'));

alter table public.daily_metric_summaries drop constraint daily_metric_summaries_source_kind_check;
alter table public.daily_metric_summaries add constraint daily_metric_summaries_source_kind_check
  check (source_kind in ('healthkit_aggregate', 'csv_aggregate', 'health_auto_export_aggregate'));

-- Only the Edge Function's service role may assert this bridge provenance.
drop policy daily_metric_summaries_insert_own on public.daily_metric_summaries;
create policy daily_metric_summaries_insert_own on public.daily_metric_summaries for insert to authenticated
  with check ((select auth.uid()) = user_id
    and source_kind <> 'health_auto_export_aggregate'
    and (select private.has_active_sync_consent('derived_metrics')));
drop policy daily_metric_summaries_update_own on public.daily_metric_summaries;
create policy daily_metric_summaries_update_own on public.daily_metric_summaries for update to authenticated
  using ((select auth.uid()) = user_id and source_kind <> 'health_auto_export_aggregate')
  with check ((select auth.uid()) = user_id
    and source_kind <> 'health_auto_export_aggregate'
    and (select private.has_active_sync_consent('derived_metrics')));

create table public.health_bridge_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  token_hash text unique not null check (char_length(token_hash) = 64),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  last_sync_at timestamptz,
  last_daily_sync_at timestamptz,
  last_intraday_sync_at timestamptz,
  last_error text
);
alter table public.health_bridge_connections enable row level security;
revoke all on public.health_bridge_connections from public, anon, authenticated;

create table public.intraday_metric_summaries (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket_start timestamptz not null,
  local_date date not null,
  timezone_identifier text not null check (char_length(timezone_identifier) between 1 and 64),
  metric_kind text not null check (metric_kind in ('active_energy', 'steps', 'heart_rate')),
  value double precision not null check (value >= 0 and value < 'Infinity'::double precision),
  unit text not null,
  aggregation text not null check (aggregation in ('sum', 'mean')),
  source_kind text not null default 'health_auto_export_aggregate'
    check (source_kind = 'health_auto_export_aggregate'),
  updated_at timestamptz not null default now(),
  primary key (user_id, bucket_start, metric_kind, source_kind),
  constraint intraday_metric_unit check (
    (metric_kind = 'active_energy' and unit = 'kcal' and aggregation = 'sum') or
    (metric_kind = 'steps' and unit = 'count' and aggregation = 'sum') or
    (metric_kind = 'heart_rate' and unit = 'bpm' and aggregation = 'mean')
  )
);
create index intraday_metric_owner_date_idx on public.intraday_metric_summaries(user_id, local_date desc);
alter table public.intraday_metric_summaries enable row level security;
revoke all on public.intraday_metric_summaries from public, anon, authenticated;
grant select, delete on public.intraday_metric_summaries to authenticated;
create policy intraday_select_own on public.intraday_metric_summaries for select to authenticated
  using ((select auth.uid()) = user_id);
create policy intraday_delete_own on public.intraday_metric_summaries for delete to authenticated
  using ((select auth.uid()) = user_id);

create table public.sleep_stage_summaries (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  stage text not null check (stage in ('core', 'deep', 'rem', 'asleep', 'in_bed')),
  minutes double precision not null check (minutes >= 0 and minutes <= 1440),
  source_kind text not null default 'health_auto_export_aggregate'
    check (source_kind = 'health_auto_export_aggregate'),
  updated_at timestamptz not null default now(),
  primary key(user_id, local_date, stage, source_kind)
);
alter table public.sleep_stage_summaries enable row level security;
revoke all on public.sleep_stage_summaries from public, anon, authenticated;
grant select, delete on public.sleep_stage_summaries to authenticated;
create policy sleep_stage_select_own on public.sleep_stage_summaries for select to authenticated
  using ((select auth.uid()) = user_id);
create policy sleep_stage_delete_own on public.sleep_stage_summaries for delete to authenticated
  using ((select auth.uid()) = user_id);
