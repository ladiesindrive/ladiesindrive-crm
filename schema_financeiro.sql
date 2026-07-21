-- Ladies in Drive — Módulo Financeiro (vendas/parcelas, contas a pagar,
-- metas) + aniversário de leads e parceiros
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera dados existentes; só adiciona tabelas e 2 colunas novas.

create table public.vendas (
  id bigint generated always as identity primary key,
  lead_id bigint references public.leads(id) on delete cascade,
  servico_produto text,
  preco_unitario numeric,
  preco_total numeric,
  forma_pagamento text,
  parcelado boolean default false,
  num_parcelas integer default 1,
  criado_em timestamptz default now()
);

create table public.venda_parcelas (
  id bigint generated always as identity primary key,
  venda_id bigint references public.vendas(id) on delete cascade,
  numero_parcela integer,
  valor numeric,
  forma_pagamento text,
  data_prevista date,
  data_realizada date,
  status text default 'Pendente',
  criado_em timestamptz default now()
);

create table public.contas_pagar (
  id bigint generated always as identity primary key,
  descricao text,
  categoria text,
  valor numeric,
  parceiro_id bigint references public.parceiros(id) on delete set null,
  vencimento date,
  data_pagamento date,
  status text default 'Pendente',
  criado_em timestamptz default now()
);

create table public.metas_financeiras (
  id bigint generated always as identity primary key,
  mes integer,
  ano integer,
  meta_faturamento numeric,
  meta_lucro numeric,
  criado_em timestamptz default now()
);

alter table public.vendas enable row level security;
alter table public.venda_parcelas enable row level security;
alter table public.contas_pagar enable row level security;
alter table public.metas_financeiras enable row level security;

create policy "Autenticados podem tudo - vendas" on public.vendas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - venda_parcelas" on public.venda_parcelas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - contas_pagar" on public.contas_pagar
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - metas_financeiras" on public.metas_financeiras
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Aniversário: já existe em clientes_transporte, faltava em leads e parceiros
alter table public.leads add column if not exists aniversario date;
alter table public.parceiros add column if not exists aniversario date;
