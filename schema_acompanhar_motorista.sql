-- Ladies in Drive — mostra motorista (nome, carro, placa) pra cliente na
-- página pública de acompanhamento (site/acompanhar.html), só depois que
-- a motorista aceita a corrida (não enquanto está só ofertada a várias).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

alter table public.motoristas
  add column if not exists placa text;

-- Precisa dropar antes: create or replace não deixa mudar o tipo de retorno
-- (adicionar colunas) de uma função existente.
drop function if exists public.get_viagem_por_token(uuid);

create or replace function public.get_viagem_por_token(p_token uuid)
returns table (
  status text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  preco_cotado numeric,
  motorista_nome text,
  motorista_veiculo text,
  motorista_placa text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    v.status,
    v.origem_endereco,
    v.destino_endereco,
    v.data,
    v.horario_partida,
    v.preco_cotado,
    m.nome as motorista_nome,
    m.veiculo as motorista_veiculo,
    m.placa as motorista_placa
  from public.viagens v
  left join public.motoristas m on m.id = v.motorista_id_confirmada
  where v.tracking_token = p_token;
$$;

grant execute on function public.get_viagem_por_token(uuid) to anon;
