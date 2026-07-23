-- Ladies in Drive — Site e redes sociais dos parceiros
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.parceiro_links (
  id bigint generated always as identity primary key,
  parceiro_id bigint references public.parceiros(id) on delete cascade,
  tipo text default 'Site',
  url text,
  criado_em timestamptz default now()
);

alter table public.parceiro_links enable row level security;

create policy "Autenticados podem tudo - parceiro_links" on public.parceiro_links
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
