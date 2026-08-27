-- Go Ladies — Duração prevista da viagem (min), usada pra calcular
-- sozinho o horário previsto de chegada a partir do horário de partida.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.viagens
  add column if not exists duracao_prevista_min numeric;
