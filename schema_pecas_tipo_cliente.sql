-- Ladies in Drive — Peças: tipo de cliente (Pessoa física / Empresa)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma linha existente (coluna nova, com default).

alter table public.pecas_pedidos
  add column if not exists tipo_cliente text default 'Pessoa física'
  check (tipo_cliente in ('Pessoa física','Empresa'));
