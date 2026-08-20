-- Ladies in Drive — público-alvo da divulgação (cursos, treinamentos,
-- encontros da rede de apoio, eventos). Controla o que aparece no painel
-- da motorista — só o que for marcado "Motoristas".
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.divulgacoes
  add column if not exists publico_alvo text;
