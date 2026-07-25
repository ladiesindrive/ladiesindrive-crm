-- Ladies in Drive — Divulgação (Eventos e Cursos: próprios, de terceiros e com comissão)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.divulgacoes (
  id bigint generated always as identity primary key,
  titulo text not null,
  formato text not null default 'Evento' check (formato in ('Evento','Curso')),
  tipo text not null default 'Terceiro - divulgação' check (tipo in ('Próprio Ladies','Terceiro - divulgação','Terceiro - com comissão')),
  parceiro_id bigint references public.parceiros(id) on delete set null,
  descricao text,
  data_inicio date,
  data_fim date,
  carga_horaria text,
  local text,
  link_inscricao text,
  preco numeric,
  comissao_percentual numeric,
  status text default 'Planejado',
  notas text,
  criado_em timestamptz default now()
);

alter table public.divulgacoes enable row level security;

create policy "Autenticados podem tudo - divulgacoes" on public.divulgacoes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
