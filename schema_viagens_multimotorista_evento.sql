-- Go Ladies — Viagens: múltiplas motoristas por viagem e tipo de
-- serviço "Evento" com descrição própria.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não apaga a coluna antiga motorista_id (fica sem uso, mas os dados continuam lá).

alter table public.viagens
  add column if not exists motorista_ids bigint[],
  add column if not exists evento_descricao text;

-- Migra a motorista já cadastrada nas viagens existentes pro novo campo (array)
update public.viagens
  set motorista_ids = array[motorista_id]
  where motorista_id is not null and motorista_ids is null;
