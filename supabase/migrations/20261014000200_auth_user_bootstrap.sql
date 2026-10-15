-- Create the minimum account-owned records for every new Auth identity.
-- No provider metadata or biometric data is copied into the application schema.
create function private.bootstrap_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id)
    values (new.id)
    on conflict (id) do nothing;

    insert into public.user_settings (user_id)
    values (new.id)
    on conflict (user_id) do nothing;

    return new;
end;
$$;

revoke all on function private.bootstrap_auth_user() from public, anon, authenticated;

create trigger on_auth_user_created_biopulse
    after insert on auth.users
    for each row execute function private.bootstrap_auth_user();
