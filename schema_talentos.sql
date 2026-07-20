-- Ladies in Drive — Banco de Talentos (captação de motoristas parceiras)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente (leads, parceiros, orcamentos).

create table public.candidatas (
  id bigint generated always as identity primary key,
  nome text not null,
  whatsapp text not null,
  area_interesse text default 'Motorista',
  cnh_categoria text,
  cnh_ear boolean,
  curso_conduapp boolean,
  curso_transporte_infantil boolean,
  regiao text,
  disponibilidade text,
  veiculo_proprio boolean,
  veiculo_modelo text,
  experiencia text,
  motivacao text,
  status text default 'Nova',
  criado_em timestamptz default now()
);

-- Segurança: candidatura vem do site, sem login (papel anônimo).
-- Anônimo só pode INSERIR (nunca ler/editar/apagar — protege dado pessoal).
-- Usuária autenticada (painel do CRM) tem acesso completo, mesmo padrão
-- já usado em leads/parceiros/orcamentos.
alter table public.candidatas enable row level security;

create policy "Anonimo pode inserir - candidatas" on public.candidatas
  for insert to anon with check (true);

create policy "Autenticados podem tudo - candidatas" on public.candidatas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
