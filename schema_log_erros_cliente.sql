-- Go Ladies — registro automático de erros do navegador (login
-- travando, ações travando, exceções JS não tratadas) direto no Supabase,
-- pra dar pra investigar depois sem precisar pegar o problema acontecendo
-- ao vivo com o F12 aberto.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

create table if not exists public.crm_erros_cliente (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  mensagem text not null check (length(mensagem) <= 2000),
  contexto text,
  pagina text,
  user_agent text
);

alter table public.crm_erros_cliente enable row level security;

-- Registra mesmo sem estar logada ainda (ex: login travando antes de
-- autenticar) — mas ninguém de fora consegue ler o que foi registrado.
create policy "Qualquer um pode registrar erro" on public.crm_erros_cliente
  for insert
  with check (true);

create policy "Staff pode ver erros registrados" on public.crm_erros_cliente
  for select
  using (auth.role() = 'authenticated' and public.motorista_id_atual() is null);
