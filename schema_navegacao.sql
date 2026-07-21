-- Ladies in Drive — Endereços de parceiros + histórico de conversas de leads
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.parceiro_enderecos (
  id bigint generated always as identity primary key,
  parceiro_id bigint references public.parceiros(id) on delete cascade,
  endereco text,
  descricao text,
  criado_em timestamptz default now()
);

create table public.lead_interacoes (
  id bigint generated always as identity primary key,
  lead_id bigint references public.leads(id) on delete cascade,
  data date,
  assunto text,
  proximos_passos text,
  criado_em timestamptz default now()
);

alter table public.parceiro_enderecos enable row level security;
alter table public.lead_interacoes enable row level security;

create policy "Autenticados podem tudo - parceiro_enderecos" on public.parceiro_enderecos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - lead_interacoes" on public.lead_interacoes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
