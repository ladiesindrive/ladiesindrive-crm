-- Go Ladies — Viagens: separa data de horário de partida/chegada, e
-- adiciona dias da semana (pra clientes fixas, ex: segunda a sexta).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não apaga as colunas antigas data_hora/data_hora_chegada (ficam sem uso).

alter table public.viagens
  add column if not exists data date,
  add column if not exists horario_partida time,
  add column if not exists horario_chegada time,
  add column if not exists dias_semana text;

-- Migra os horários já cadastrados pro novo formato (data separada do horário)
update public.viagens
  set data = data_hora::date,
      horario_partida = data_hora::time
  where data_hora is not null and data is null;

update public.viagens
  set horario_chegada = data_hora_chegada::time
  where data_hora_chegada is not null and horario_chegada is null;
