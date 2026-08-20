-- Ladies in Drive — expõe a duração prevista da viagem (min) pra função que
-- alimenta o painel da motorista (crm/schema_viagens_motorista_com_cliente.sql),
-- pra ela ver o tempo previsto no cartão da corrida, não só a distância.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

drop function if exists public.viagens_da_motorista();

create or replace function public.viagens_da_motorista()
returns table (
  id bigint,
  status text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  distancia_km numeric,
  duracao_prevista_min numeric,
  preco_motorista numeric,
  motorista_id_confirmada bigint,
  preparacao_confirmada boolean,
  saida_confirmada boolean,
  cliente_nome text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    v.id, v.status, v.origem_endereco, v.destino_endereco, v.data, v.horario_partida,
    v.distancia_km, v.duracao_prevista_min, v.preco_motorista, v.motorista_id_confirmada,
    v.preparacao_confirmada, v.saida_confirmada,
    c.nome as cliente_nome
  from public.viagens v
  left join public.clientes_transporte c on c.id = v.cliente_id
  where public.motorista_id_atual() = any(v.motorista_ids)
  order by v.data asc;
$$;

grant execute on function public.viagens_da_motorista() to authenticated;
