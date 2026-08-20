-- Ladies in Drive — o painel da motorista não pode ler a tabela
-- clientes_transporte direto (é staff-only por segurança, desde a correção
-- que impede motorista de ver dados de negócio). Esta função devolve só o
-- necessário pra ela avaliar a oferta: nome da cliente + dados da viagem,
-- nunca WhatsApp nem endereço de cadastro da cliente.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

create or replace function public.viagens_da_motorista()
returns table (
  id bigint,
  status text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  distancia_km numeric,
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
    v.distancia_km, v.preco_motorista, v.motorista_id_confirmada,
    v.preparacao_confirmada, v.saida_confirmada,
    c.nome as cliente_nome
  from public.viagens v
  left join public.clientes_transporte c on c.id = v.cliente_id
  where public.motorista_id_atual() = any(v.motorista_ids)
  order by v.data asc;
$$;

grant execute on function public.viagens_da_motorista() to authenticated;
