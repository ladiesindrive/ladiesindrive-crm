-- Ladies in Drive — Banco de Talentos com curadoria (vagas de empresas parceiras)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.vagas (
  id bigint generated always as identity primary key,
  titulo text not null,
  empresa_parceira_id bigint references public.parceiros(id) on delete set null,
  empresa_nome text,
  descricao text,
  requisitos text,
  local text,
  tipo_vaga text,
  faixa_salarial text,
  status text default 'Em triagem',
  fee_modelo text,
  fee_valor numeric,
  notas text,
  criado_em timestamptz default now()
);

create table public.vagas_candidatas (
  id bigint generated always as identity primary key,
  vaga_id bigint references public.vagas(id) on delete cascade,
  nome text not null,
  whatsapp text not null,
  curriculo_link text,
  status text default 'Nova',
  notas text,
  criado_em timestamptz default now()
);

alter table public.vagas enable row level security;
alter table public.vagas_candidatas enable row level security;

-- Empresa publica vaga sem login (formulário público no site).
-- Trava de curadoria: mesmo que o payload tente mandar outro status,
-- a linha só entra como 'Em triagem' — só aparece no site quando
-- a Jú aprovar manualmente pelo CRM e mudar o status pra 'Aberta'.
create policy "Anonimo pode inserir - vagas" on public.vagas
  for insert to anon with check (status = 'Em triagem');

-- Site precisa listar vagas abertas publicamente, sem login.
create policy "Anonimo pode ler vagas abertas" on public.vagas
  for select to anon using (status = 'Aberta');

-- Candidata se candidata sem login — só pra vaga que está de fato aberta.
create policy "Anonimo pode inserir - vagas_candidatas" on public.vagas_candidatas
  for insert to anon with check (
    status = 'Nova'
    and exists (select 1 from public.vagas v where v.id = vaga_id and v.status = 'Aberta')
  );

-- Painel do CRM: acesso completo, mesmo padrão de leads/parceiros/orcamentos.
create policy "Autenticados podem tudo - vagas" on public.vagas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - vagas_candidatas" on public.vagas_candidatas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
