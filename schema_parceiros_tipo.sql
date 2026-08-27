-- Go Ladies — Tipo de parceria (Mensalidade / Patrocínio / Embaixadora)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma linha existente (coluna nova, opcional).

alter table public.parceiros
  add column if not exists tipo_parceria text
  check (tipo_parceria in ('Mensalidade','Patrocínio','Embaixadora'));
