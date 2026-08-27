-- Go Ladies — funções novas pro painel ampliado da motorista:
-- histórico completo de ofertas (aceitas ou não, com motivo), recusar uma
-- oferta, e ver cursos/eventos marcados pra ela. Depende de
-- schema_viagem_ofertas.sql, schema_pagamento_motorista_previsto.sql e
-- schema_divulgacoes_publico_alvo.sql já terem rodado antes.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

-- ── Histórico único: cobre Ofertas pendentes, Minhas viagens e Histórico,
-- o painel filtra por "desfecho" e "status_viagem" no front-end. Traz
-- também o pagamento (previsto x realizado x comprovante) de cada corrida.
drop function if exists public.historico_ofertas_motorista();

create or replace function public.historico_ofertas_motorista()
returns table (
  viagem_id bigint,
  desfecho text,
  ofertada_em timestamptz,
  respondida_em timestamptz,
  status_viagem text,
  data date,
  horario_partida time,
  horario_chegada time,
  distancia_km numeric,
  duracao_prevista_min numeric,
  preco_motorista numeric,
  origem_endereco text,
  destino_endereco text,
  cliente_nome text,
  motorista_id_confirmada bigint,
  preparacao_confirmada boolean,
  saida_confirmada boolean,
  pgto_status text,
  pgto_data_prevista date,
  pgto_data_realizada date,
  pgto_valor_repassado numeric,
  pgto_comprovante_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    o.viagem_id, o.desfecho, o.ofertada_em, o.respondida_em,
    v.status, v.data, v.horario_partida, v.horario_chegada,
    v.distancia_km, v.duracao_prevista_min, v.preco_motorista,
    v.origem_endereco, v.destino_endereco,
    c.nome as cliente_nome,
    v.motorista_id_confirmada, v.preparacao_confirmada, v.saida_confirmada,
    pg.status as pgto_status, pg.data_prevista_pagamento, pg.data_pagamento,
    pg.valor_repassado, pg.comprovante_url
  from public.viagem_ofertas o
  join public.viagens v on v.id = o.viagem_id
  left join public.clientes_transporte c on c.id = v.cliente_id
  left join public.pagamentos_motorista pg on pg.viagem_id = v.id
  where o.motorista_id = public.motorista_id_atual()
  order by v.data desc nulls last, o.ofertada_em desc;
$$;

grant execute on function public.historico_ofertas_motorista() to authenticated;

-- ── Recusar uma oferta pendente: registra o desfecho e tira ela da lista
-- de candidatas da viagem (equipe vê que precisa oferecer pra outra).
create or replace function public.recusar_viagem_motorista(p_viagem_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meu_id bigint := public.motorista_id_atual();
  v_linhas int;
begin
  if v_meu_id is null then
    raise exception 'Login não vinculado a nenhuma motorista.';
  end if;

  update public.viagem_ofertas
  set desfecho = 'Recusada', respondida_em = now()
  where viagem_id = p_viagem_id and motorista_id = v_meu_id and desfecho = 'Pendente';

  get diagnostics v_linhas = row_count;

  if v_linhas > 0 then
    update public.viagens
    set motorista_ids = array_remove(motorista_ids, v_meu_id)
    where id = p_viagem_id;
  end if;

  return v_linhas > 0;
end;
$$;

grant execute on function public.recusar_viagem_motorista(bigint) to authenticated;

-- ── Aceitar (atualizada): marca a própria oferta como Aceita e as outras
-- pendentes da mesma viagem como Perdida (pra quem não foi escolhida ver
-- "outra motorista aceitou primeiro" no histórico, sem culpa nenhuma dela).
create or replace function public.aceitar_viagem_motorista(p_viagem_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meu_id bigint := public.motorista_id_atual();
  v_linhas int;
begin
  if v_meu_id is null then
    raise exception 'Login não vinculado a nenhuma motorista.';
  end if;

  update public.viagens
  set motorista_id_confirmada = v_meu_id,
      motorista_ids = array[v_meu_id],
      status = case when status = 'Solicitada' then 'Confirmada' else status end
  where id = p_viagem_id
    and motorista_id_confirmada is null
    and v_meu_id = any(motorista_ids);

  get diagnostics v_linhas = row_count;

  if v_linhas > 0 then
    update public.viagem_ofertas
    set desfecho = 'Aceita', respondida_em = now()
    where viagem_id = p_viagem_id and motorista_id = v_meu_id;

    update public.viagem_ofertas
    set desfecho = 'Perdida', respondida_em = now()
    where viagem_id = p_viagem_id and motorista_id != v_meu_id and desfecho = 'Pendente';
  end if;

  return v_linhas > 0;
end;
$$;

grant execute on function public.aceitar_viagem_motorista(bigint) to authenticated;

-- ── Cursos, treinamentos e encontros da rede de apoio marcados pra
-- motoristas em Divulgação. divulgacoes é staff-only (RLS), por isso a
-- motorista precisa dessa porta segura, mesmo padrão de viagens_da_motorista.
create or replace function public.divulgacoes_da_motorista()
returns table (
  id bigint,
  titulo text,
  formato text,
  tipo text,
  descricao text,
  data_inicio date,
  data_fim date,
  carga_horaria text,
  local text,
  link_inscricao text,
  preco numeric,
  status text
)
language sql
security definer
set search_path = public
stable
as $$
  select id, titulo, formato, tipo, descricao, data_inicio, data_fim,
    carga_horaria, local, link_inscricao, preco, status
  from public.divulgacoes
  where publico_alvo like '%Motoristas%'
  order by data_inicio asc nulls last;
$$;

grant execute on function public.divulgacoes_da_motorista() to authenticated;
