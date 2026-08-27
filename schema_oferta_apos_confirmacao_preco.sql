-- Go Ladies — a oferta só chega na motorista depois que a cliente
-- aceita o valor, e aí chega sozinha.
--
-- Problema que isso corrige: a oferta era criada no instante em que você
-- marcava as motoristas em viagens.motorista_ids (trigger de
-- schema_viagem_ofertas.sql), então elas viam a corrida antes da cliente
-- confirmar o preço; e se alguma aceitasse nesse momento, a viagem ficava
-- com motorista confirmada mas presa no status "Aguardando cliente
-- confirmar preço". Do outro lado, depois do "1" da cliente a viagem
-- voltava pra "Solicitada" e ficava parada esperando você entrar no CRM.
--
-- Regra nova: você marca as motoristas junto com a cotação, mas a oferta
-- fica invisível pra elas enquanto tiver preço cotado sem confirmação da
-- cliente. Quando a cliente aceita (confirmar_preco_cliente), a oferta abre
-- sozinha no painel delas e o n8n manda o WhatsApp avisando.
--
-- Viagem sem preço cotado (combinado por fora, teste, cortesia) continua
-- aparecendo na hora, como sempre foi. Se você cotou mas não quer esperar o
-- WhatsApp da cliente, marque "Preço já acertado com a cliente" no modal da
-- viagem no CRM, que libera na hora.
--
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.
-- Seguro rodar de novo se rodar por engano.
-- Depende de: schema_viagem_ofertas.sql, schema_motorista_painel_v2.sql,
-- schema_confirmacao_preco_cliente.sql e schema_confirmacao_codigo_avaliacao.sql.

-- ── Regra única de "essa oferta já pode aparecer pra motorista?", usada
-- pelas três funções abaixo pra nunca sair de sincronia entre elas.
create or replace function public.oferta_liberada_para_motoristas(
  p_status text, p_preco_cotado numeric, p_preco_confirmado boolean
)
returns boolean
language sql
immutable
as $$
  select coalesce(p_status, '') not in (
           'Aguardando cliente confirmar preço',
           'Preço recusado pela cliente',
           'Cancelada'
         )
     and (coalesce(p_preco_confirmado, false) or p_preco_cotado is null);
$$;

grant execute on function public.oferta_liberada_para_motoristas(text, numeric, boolean) to authenticated, service_role;

-- ── Coluna de controle do aviso por WhatsApp, uma por oferta (a mesma
-- viagem pode ser oferecida pra várias motoristas). O backfill roda só na
-- criação da coluna: marca as ofertas que já existiam como avisadas, senão
-- o primeiro polling dispararia mensagem de corrida antiga pra todo mundo.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'viagem_ofertas' and column_name = 'avisada_em'
  ) then
    alter table public.viagem_ofertas add column avisada_em timestamptz;
    update public.viagem_ofertas set avisada_em = coalesce(respondida_em, ofertada_em, now());
  end if;
end $$;

-- ── Painel da motorista (atualizada): esconde as ofertas ainda pendentes
-- de viagem cujo preço a cliente não confirmou. Ofertas já respondidas
-- (Aceita, Recusada, Perdida) continuam aparecendo no histórico dela sempre.
-- Colunas iguais às de schema_confirmacao_codigo_avaliacao.sql.
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
  codigo_inicio text,
  ja_avaliou_cliente boolean,
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
    v.codigo_inicio,
    exists (select 1 from public.avaliacoes a where a.viagem_id = v.id and a.nota_cliente is not null) as ja_avaliou_cliente,
    pg.status as pgto_status, pg.data_prevista_pagamento, pg.data_pagamento,
    pg.valor_repassado, pg.comprovante_url
  from public.viagem_ofertas o
  join public.viagens v on v.id = o.viagem_id
  left join public.clientes_transporte c on c.id = v.cliente_id
  left join public.pagamentos_motorista pg on pg.viagem_id = v.id
  where o.motorista_id = public.motorista_id_atual()
    and (
      o.desfecho <> 'Pendente'
      or public.oferta_liberada_para_motoristas(v.status, v.preco_cotado, v.preco_confirmado_cliente)
    )
  order by v.data desc nulls last, o.ofertada_em desc;
$$;

revoke execute on function public.historico_ofertas_motorista() from public;
grant execute on function public.historico_ofertas_motorista() to authenticated;

-- ── Aceitar (atualizada): mesma função de
-- schema_confirmacao_codigo_avaliacao.sql (confirma a motorista, gera o
-- código de 4 dígitos, marca as outras ofertas como Perdida), agora com a
-- trava do preço na frente. É defesa em profundidade: a oferta já nem
-- aparece no painel, isso cobre a tela que ficou aberta antes da cliente
-- responder.
create or replace function public.aceitar_viagem_motorista(p_viagem_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meu_id bigint := public.motorista_id_atual();
  v_linhas int;
  v_status text;
  v_preco numeric;
  v_confirmado boolean;
begin
  if v_meu_id is null then
    raise exception 'Login não vinculado a nenhuma motorista.';
  end if;

  select status, preco_cotado, preco_confirmado_cliente
    into v_status, v_preco, v_confirmado
  from public.viagens where id = p_viagem_id;

  if v_status is null then
    return false;
  end if;

  if not public.oferta_liberada_para_motoristas(v_status, v_preco, v_confirmado) then
    raise exception 'Essa corrida ainda não está liberada: a cliente não confirmou o valor.';
  end if;

  update public.viagens
  set motorista_id_confirmada = v_meu_id,
      motorista_ids = array[v_meu_id],
      status = case when status = 'Solicitada' then 'Confirmada' else status end,
      codigo_inicio = case when status = 'Solicitada' then lpad(floor(random() * 10000)::text, 4, '0') else codigo_inicio end
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

revoke execute on function public.aceitar_viagem_motorista(bigint) from public;
grant execute on function public.aceitar_viagem_motorista(bigint) to authenticated;

-- ── Chamada pelo n8n a cada poucos minutos: quais motoristas ainda não
-- foram avisadas de uma oferta que já está aberta pra elas. Só corrida sem
-- motorista confirmada e com data de hoje pra frente.
create or replace function public.ofertas_aguardando_aviso()
returns table (
  oferta_id bigint,
  viagem_id bigint,
  motorista_nome text,
  motorista_whatsapp text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  distancia_km numeric,
  duracao_prevista_min numeric,
  preco_motorista numeric
)
language sql
stable
as $$
  select o.id, v.id, m.nome, m.whatsapp,
         v.origem_endereco, v.destino_endereco, v.data, v.horario_partida,
         v.distancia_km, v.duracao_prevista_min, v.preco_motorista
  from public.viagem_ofertas o
  join public.viagens v on v.id = o.viagem_id
  join public.motoristas m on m.id = o.motorista_id
  where o.desfecho = 'Pendente'
    and o.avisada_em is null
    and v.motorista_id_confirmada is null
    and m.whatsapp is not null
    and (v.data is null or v.data >= current_date)
    and public.oferta_liberada_para_motoristas(v.status, v.preco_cotado, v.preco_confirmado_cliente)
  order by o.ofertada_em;
$$;

revoke execute on function public.ofertas_aguardando_aviso() from public, anon, authenticated;
grant execute on function public.ofertas_aguardando_aviso() to service_role;

-- ── Chamada pelo n8n logo depois de mandar a mensagem, pra não repetir no
-- polling seguinte.
create or replace function public.marcar_oferta_avisada(p_oferta_id bigint)
returns void
language sql
as $$
  update public.viagem_ofertas set avisada_em = now() where id = p_oferta_id;
$$;

revoke execute on function public.marcar_oferta_avisada(bigint) from public, anon, authenticated;
grant execute on function public.marcar_oferta_avisada(bigint) to service_role;
