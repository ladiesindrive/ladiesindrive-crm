-- Go Ladies — Pedidos de orçamento de transporte
-- Adiciona à tabela "viagens" já existente: horário previsto de chegada,
-- distância (km) e motivo de não fechamento (quando a viagem é cancelada).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.viagens
  add column if not exists data_hora_chegada timestamptz,
  add column if not exists distancia_km numeric,
  add column if not exists motivo_perda text;
