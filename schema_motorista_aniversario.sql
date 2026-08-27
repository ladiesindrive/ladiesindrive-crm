-- Go Ladies — Aniversário no cadastro de motorista
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.motoristas
  add column if not exists aniversario date;
