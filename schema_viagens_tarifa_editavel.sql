-- Go Ladies — Tarifa fixa e valor/km editáveis por viagem
-- Antes, tarifa fixa e valor/km eram só constantes fixas no código (mesmas
-- pra toda viagem). Agora cada viagem guarda o valor usado no cálculo dela,
-- editável caso a Jú negocie diferente do padrão.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.viagens
  add column if not exists tarifa_fixa numeric,
  add column if not exists valor_km numeric;
