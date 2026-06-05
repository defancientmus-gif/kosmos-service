-- Kosmos Service cloud core.
-- Run in a separate Supabase project for this repository only.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  business_name text,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agent_context (
  user_id uuid primary key references auth.users(id) on delete cascade,
  ui_state jsonb not null default '{}'::jsonb,
  agent_memory jsonb not null default '{}'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  phone text,
  email text,
  source text,
  tags text[] not null default '{}'::text[],
  note text,
  external_source text,
  external_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id),
  unique (user_id, external_source, external_id)
);

create table if not exists public.crm_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid,
  device_brand text,
  device_model text,
  device_serial text,
  problem_description text,
  work_notes text,
  status text not null default 'new',
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  price_estimate numeric(12, 2),
  amount_due numeric(12, 2),
  currency char(3) not null default 'RUB',
  source text,
  external_source text,
  external_id text,
  accepted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id),
  unique (user_id, external_source, external_id),
  foreign key (client_id, user_id) references public.crm_clients(id, user_id)
);

create table if not exists public.crm_order_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null,
  kind text not null default 'photo' check (kind in ('photo', 'video', 'document', 'receipt', 'other')),
  storage_bucket text,
  storage_path text,
  original_name text,
  mime_type text,
  size_bytes bigint,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id),
  foreign key (order_id, user_id) references public.crm_orders(id, user_id) on delete cascade
);

create table if not exists public.money_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  account_type text not null default 'cash' check (account_type in ('cash', 'bank', 'card', 'terminal', 'other')),
  bank_name text,
  currency char(3) not null default 'RUB',
  details jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table if not exists public.document_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  document_type text not null default 'other',
  source text,
  status text not null default 'inbox' check (status in ('inbox', 'review', 'ready', 'archived', 'rejected')),
  local_hint text,
  storage_bucket text,
  storage_path text,
  received_at timestamptz,
  issued_on date,
  due_on date,
  amount numeric(12, 2),
  currency char(3) not null default 'RUB',
  counterparty text,
  needs_accountant boolean not null default false,
  note text,
  extracted jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table if not exists public.money_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid,
  related_order_id uuid,
  related_document_id uuid,
  direction text not null check (direction in ('income', 'expense', 'transfer')),
  amount numeric(12, 2) not null check (amount >= 0),
  currency char(3) not null default 'RUB',
  occurred_on date not null default current_date,
  category text,
  counterparty text,
  purpose text,
  status text not null default 'draft' check (status in ('draft', 'planned', 'paid', 'cancelled', 'reconciled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id),
  foreign key (account_id, user_id) references public.money_accounts(id, user_id),
  foreign key (related_order_id, user_id) references public.crm_orders(id, user_id),
  foreign key (related_document_id, user_id) references public.document_records(id, user_id)
);

create table if not exists public.payment_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  counterparty text,
  bank_details jsonb not null default '{}'::jsonb,
  purpose_template text,
  default_amount numeric(12, 2),
  currency char(3) not null default 'RUB',
  tax_hint text,
  requires_review boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table if not exists public.obligations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  related_document_id uuid,
  title text not null,
  category text,
  due_on date not null,
  amount numeric(12, 2),
  currency char(3) not null default 'RUB',
  status text not null default 'planned' check (status in ('planned', 'done', 'cancelled', 'overdue')),
  repeat_rule text,
  responsible_party text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id),
  foreign key (related_document_id, user_id) references public.document_records(id, user_id)
);

create table if not exists public.agent_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null,
  status text not null default 'draft' check (status in ('draft', 'queued', 'needs_confirmation', 'done', 'failed', 'cancelled')),
  target_table text,
  target_id uuid,
  input jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  error text,
  requires_confirmation boolean not null default true,
  confirmed_at timestamptz,
  executed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists crm_clients_user_updated_idx on public.crm_clients(user_id, updated_at desc);
create index if not exists crm_clients_user_phone_idx on public.crm_clients(user_id, phone);
create index if not exists crm_clients_user_name_idx on public.crm_clients(user_id, lower(display_name));
create index if not exists crm_orders_user_status_idx on public.crm_orders(user_id, status, updated_at desc);
create index if not exists crm_orders_user_client_idx on public.crm_orders(user_id, client_id);
create index if not exists crm_order_files_user_order_idx on public.crm_order_files(user_id, order_id);
create index if not exists money_transactions_user_date_idx on public.money_transactions(user_id, occurred_on desc);
create index if not exists money_transactions_user_status_idx on public.money_transactions(user_id, status);
create index if not exists document_records_user_status_idx on public.document_records(user_id, status, updated_at desc);
create index if not exists obligations_user_due_idx on public.obligations(user_id, due_on, status);
create index if not exists agent_actions_user_created_idx on public.agent_actions(user_id, created_at desc);
create index if not exists agent_actions_user_status_idx on public.agent_actions(user_id, status);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists agent_context_set_updated_at on public.agent_context;
create trigger agent_context_set_updated_at before update on public.agent_context
for each row execute function public.set_updated_at();

drop trigger if exists crm_clients_set_updated_at on public.crm_clients;
create trigger crm_clients_set_updated_at before update on public.crm_clients
for each row execute function public.set_updated_at();

drop trigger if exists crm_orders_set_updated_at on public.crm_orders;
create trigger crm_orders_set_updated_at before update on public.crm_orders
for each row execute function public.set_updated_at();

drop trigger if exists crm_order_files_set_updated_at on public.crm_order_files;
create trigger crm_order_files_set_updated_at before update on public.crm_order_files
for each row execute function public.set_updated_at();

drop trigger if exists money_accounts_set_updated_at on public.money_accounts;
create trigger money_accounts_set_updated_at before update on public.money_accounts
for each row execute function public.set_updated_at();

drop trigger if exists document_records_set_updated_at on public.document_records;
create trigger document_records_set_updated_at before update on public.document_records
for each row execute function public.set_updated_at();

drop trigger if exists money_transactions_set_updated_at on public.money_transactions;
create trigger money_transactions_set_updated_at before update on public.money_transactions
for each row execute function public.set_updated_at();

drop trigger if exists payment_templates_set_updated_at on public.payment_templates;
create trigger payment_templates_set_updated_at before update on public.payment_templates
for each row execute function public.set_updated_at();

drop trigger if exists obligations_set_updated_at on public.obligations;
create trigger obligations_set_updated_at before update on public.obligations
for each row execute function public.set_updated_at();

drop trigger if exists agent_actions_set_updated_at on public.agent_actions;
create trigger agent_actions_set_updated_at before update on public.agent_actions
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.agent_context enable row level security;
alter table public.crm_clients enable row level security;
alter table public.crm_orders enable row level security;
alter table public.crm_order_files enable row level security;
alter table public.money_accounts enable row level security;
alter table public.document_records enable row level security;
alter table public.money_transactions enable row level security;
alter table public.payment_templates enable row level security;
alter table public.obligations enable row level security;
alter table public.agent_actions enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select using (auth.uid() = user_id);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert with check (auth.uid() = user_id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own on public.profiles for delete using (auth.uid() = user_id);

drop policy if exists agent_context_select_own on public.agent_context;
create policy agent_context_select_own on public.agent_context for select using (auth.uid() = user_id);
drop policy if exists agent_context_insert_own on public.agent_context;
create policy agent_context_insert_own on public.agent_context for insert with check (auth.uid() = user_id);
drop policy if exists agent_context_update_own on public.agent_context;
create policy agent_context_update_own on public.agent_context for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists agent_context_delete_own on public.agent_context;
create policy agent_context_delete_own on public.agent_context for delete using (auth.uid() = user_id);

drop policy if exists crm_clients_select_own on public.crm_clients;
create policy crm_clients_select_own on public.crm_clients for select using (auth.uid() = user_id);
drop policy if exists crm_clients_insert_own on public.crm_clients;
create policy crm_clients_insert_own on public.crm_clients for insert with check (auth.uid() = user_id);
drop policy if exists crm_clients_update_own on public.crm_clients;
create policy crm_clients_update_own on public.crm_clients for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists crm_clients_delete_own on public.crm_clients;
create policy crm_clients_delete_own on public.crm_clients for delete using (auth.uid() = user_id);

drop policy if exists crm_orders_select_own on public.crm_orders;
create policy crm_orders_select_own on public.crm_orders for select using (auth.uid() = user_id);
drop policy if exists crm_orders_insert_own on public.crm_orders;
create policy crm_orders_insert_own on public.crm_orders for insert with check (auth.uid() = user_id);
drop policy if exists crm_orders_update_own on public.crm_orders;
create policy crm_orders_update_own on public.crm_orders for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists crm_orders_delete_own on public.crm_orders;
create policy crm_orders_delete_own on public.crm_orders for delete using (auth.uid() = user_id);

drop policy if exists crm_order_files_select_own on public.crm_order_files;
create policy crm_order_files_select_own on public.crm_order_files for select using (auth.uid() = user_id);
drop policy if exists crm_order_files_insert_own on public.crm_order_files;
create policy crm_order_files_insert_own on public.crm_order_files for insert with check (auth.uid() = user_id);
drop policy if exists crm_order_files_update_own on public.crm_order_files;
create policy crm_order_files_update_own on public.crm_order_files for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists crm_order_files_delete_own on public.crm_order_files;
create policy crm_order_files_delete_own on public.crm_order_files for delete using (auth.uid() = user_id);

drop policy if exists money_accounts_select_own on public.money_accounts;
create policy money_accounts_select_own on public.money_accounts for select using (auth.uid() = user_id);
drop policy if exists money_accounts_insert_own on public.money_accounts;
create policy money_accounts_insert_own on public.money_accounts for insert with check (auth.uid() = user_id);
drop policy if exists money_accounts_update_own on public.money_accounts;
create policy money_accounts_update_own on public.money_accounts for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists money_accounts_delete_own on public.money_accounts;
create policy money_accounts_delete_own on public.money_accounts for delete using (auth.uid() = user_id);

drop policy if exists document_records_select_own on public.document_records;
create policy document_records_select_own on public.document_records for select using (auth.uid() = user_id);
drop policy if exists document_records_insert_own on public.document_records;
create policy document_records_insert_own on public.document_records for insert with check (auth.uid() = user_id);
drop policy if exists document_records_update_own on public.document_records;
create policy document_records_update_own on public.document_records for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists document_records_delete_own on public.document_records;
create policy document_records_delete_own on public.document_records for delete using (auth.uid() = user_id);

drop policy if exists money_transactions_select_own on public.money_transactions;
create policy money_transactions_select_own on public.money_transactions for select using (auth.uid() = user_id);
drop policy if exists money_transactions_insert_own on public.money_transactions;
create policy money_transactions_insert_own on public.money_transactions for insert with check (auth.uid() = user_id);
drop policy if exists money_transactions_update_own on public.money_transactions;
create policy money_transactions_update_own on public.money_transactions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists money_transactions_delete_own on public.money_transactions;
create policy money_transactions_delete_own on public.money_transactions for delete using (auth.uid() = user_id);

drop policy if exists payment_templates_select_own on public.payment_templates;
create policy payment_templates_select_own on public.payment_templates for select using (auth.uid() = user_id);
drop policy if exists payment_templates_insert_own on public.payment_templates;
create policy payment_templates_insert_own on public.payment_templates for insert with check (auth.uid() = user_id);
drop policy if exists payment_templates_update_own on public.payment_templates;
create policy payment_templates_update_own on public.payment_templates for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists payment_templates_delete_own on public.payment_templates;
create policy payment_templates_delete_own on public.payment_templates for delete using (auth.uid() = user_id);

drop policy if exists obligations_select_own on public.obligations;
create policy obligations_select_own on public.obligations for select using (auth.uid() = user_id);
drop policy if exists obligations_insert_own on public.obligations;
create policy obligations_insert_own on public.obligations for insert with check (auth.uid() = user_id);
drop policy if exists obligations_update_own on public.obligations;
create policy obligations_update_own on public.obligations for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists obligations_delete_own on public.obligations;
create policy obligations_delete_own on public.obligations for delete using (auth.uid() = user_id);

drop policy if exists agent_actions_select_own on public.agent_actions;
create policy agent_actions_select_own on public.agent_actions for select using (auth.uid() = user_id);
drop policy if exists agent_actions_insert_own on public.agent_actions;
create policy agent_actions_insert_own on public.agent_actions for insert with check (auth.uid() = user_id);
drop policy if exists agent_actions_update_own on public.agent_actions;
create policy agent_actions_update_own on public.agent_actions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists agent_actions_delete_own on public.agent_actions;
create policy agent_actions_delete_own on public.agent_actions for delete using (auth.uid() = user_id);

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.agent_context to authenticated;
grant select, insert, update, delete on public.crm_clients to authenticated;
grant select, insert, update, delete on public.crm_orders to authenticated;
grant select, insert, update, delete on public.crm_order_files to authenticated;
grant select, insert, update, delete on public.money_accounts to authenticated;
grant select, insert, update, delete on public.document_records to authenticated;
grant select, insert, update, delete on public.money_transactions to authenticated;
grant select, insert, update, delete on public.payment_templates to authenticated;
grant select, insert, update, delete on public.obligations to authenticated;
grant select, insert, update, delete on public.agent_actions to authenticated;
