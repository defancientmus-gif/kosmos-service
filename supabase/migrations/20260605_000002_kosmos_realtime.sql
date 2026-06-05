-- Optional realtime support for the first synced agent/CRM tables.
-- Keep this in the same separate Supabase project as the core migration.

alter table public.profiles replica identity full;
alter table public.agent_context replica identity full;
alter table public.crm_clients replica identity full;
alter table public.crm_orders replica identity full;
alter table public.document_records replica identity full;
alter table public.obligations replica identity full;
alter table public.agent_actions replica identity full;

do $$
declare
  table_name text;
  realtime_tables text[] := array[
    'profiles',
    'agent_context',
    'crm_clients',
    'crm_orders',
    'document_records',
    'obligations',
    'agent_actions'
  ];
begin
  foreach table_name in array realtime_tables loop
    if exists (
      select 1 from pg_publication where pubname = 'supabase_realtime'
    ) and not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;
