-- Go Ladies — Observações da motorista (texto livre + data da conversa)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.motorista_observacoes (
  id bigint generated always as identity primary key,
  motorista_id bigint references public.motoristas(id) on delete cascade,
  data date,
  observacao text,
  criado_em timestamptz default now()
);

alter table public.motorista_observacoes enable row level security;

create policy "Autenticados podem tudo - motorista_observacoes" on public.motorista_observacoes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
