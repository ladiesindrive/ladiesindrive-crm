-- Ladies in Drive — Corrige leads que já têm um orçamento Aceito mas
-- ficaram paradas numa etapa anterior (ex: caso da Mirian: pediu um
-- orçamento que não fechou, depois outro que fechou, mas a etapa da lead
-- nunca avançou pra "Fechado - Ganho"/"Cliente ativo", então ela não
-- aparecia na aba Clientes).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Seguro rodar mais de uma vez (idempotente).

update public.leads
set etapa = 'Fechado - Ganho'
where etapa not in ('Fechado - Ganho', 'Cliente ativo')
  and id in (select lead_id from public.orcamentos where status = 'Aceito');
