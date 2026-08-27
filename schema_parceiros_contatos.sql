-- Go Ladies — Contatos e histórico de conversa dos parceiros
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera a tabela "parceiros" existente.

create table public.parceiro_contatos (
  id bigint generated always as identity primary key,
  parceiro_id bigint references public.parceiros(id) on delete cascade,
  tipo text default 'Celular',
  numero text,
  descricao text,
  criado_em timestamptz default now()
);

create table public.parceiro_interacoes (
  id bigint generated always as identity primary key,
  parceiro_id bigint references public.parceiros(id) on delete cascade,
  data date,
  assunto text,
  proximos_passos text,
  link_drive text,
  criado_em timestamptz default now()
);

alter table public.parceiro_contatos enable row level security;
alter table public.parceiro_interacoes enable row level security;

create policy "Autenticados podem tudo - parceiro_contatos" on public.parceiro_contatos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - parceiro_interacoes" on public.parceiro_interacoes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Migração única: leva o contato que já existia em parceiros.contato
-- (ex: os 3 parceiros de exemplo) para a nova tabela, como "Celular".
-- A coluna antiga parceiros.contato continua no banco, só não é mais usada.
insert into public.parceiro_contatos (parceiro_id, tipo, numero)
select id, 'Celular', contato from public.parceiros where contato is not null and contato <> '';
