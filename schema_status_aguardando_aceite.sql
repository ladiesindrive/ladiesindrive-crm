-- Go Ladies — status novo "Aguardando aceite de motorista".
--
-- Problema que isso resolve: o status "Solicitada" acumulava dois momentos
-- bem diferentes da viagem. Um era "acabou de entrar pelo site, ninguém
-- cotou ainda"; o outro era "a cliente já aceitou o preço, a oferta está
-- aberta e o WhatsApp já foi pra motorista, só falta alguém clicar em
-- Aceitar". No kanban os dois caíam na mesma coluna e não dava pra saber
-- qual corrida ainda precisava de atenção sua e qual já estava rodando
-- sozinha esperando resposta das motoristas.
--
-- Regra nova: quando a cliente confirma o preço no WhatsApp e a viagem já
-- tem motorista marcada, ela vai pra "Aguardando aceite de motorista" em
-- vez de voltar pra "Solicitada". Quando a motorista clica em Aceitar, vira
-- "Confirmada" como sempre foi. Viagem sem nenhuma motorista marcada ainda
-- continua indo pra "Solicitada", porque aí a bola está com você.
--
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.
-- Seguro rodar de novo se rodar por engano.
-- Depende de: schema_confirmacao_preco_cliente.sql e
-- schema_oferta_apos_confirmacao_preco.sql (roda depois dos dois).

-- ── Confirmação de preço (atualizada): mesma função de
-- schema_confirmacao_preco_cliente.sql, só muda o status de destino quando a
-- cliente aceita. A recusa continua igual.
create or replace function public.confirmar_preco_cliente(p_viagem_id bigint, p_telefone text, p_aceita boolean)
returns table (
  viagem_id bigint,
  cliente_nome text,
  cliente_whatsapp text,
  origem_endereco text,
  destino_endereco text,
  preco_cotado numeric,
  aceito boolean
)
language plpgsql
as $$
declare
  v_id bigint;
begin
  if p_viagem_id is not null then
    select v.id into v_id
    from public.viagens v
    where v.id = p_viagem_id and v.status = 'Aguardando cliente confirmar preço';
  else
    select v.id into v_id
    from public.viagens v
    join public.clientes_transporte c on c.id = v.cliente_id
    where v.status = 'Aguardando cliente confirmar preço'
      and right(regexp_replace(c.whatsapp, '\D', '', 'g'), 8) = right(regexp_replace(p_telefone, '\D', '', 'g'), 8)
    order by v.preco_confirmacao_enviada_em desc nulls last
    limit 1;
  end if;

  if v_id is null then
    return;
  end if;

  if p_aceita then
    update public.viagens
    set preco_confirmado_cliente = true,
        preco_confirmado_em = now(),
        status = case
                   when motorista_id_confirmada is not null then 'Confirmada'
                   when coalesce(array_length(motorista_ids, 1), 0) > 0 then 'Aguardando aceite de motorista'
                   else 'Solicitada'
                 end
    where id = v_id;
  else
    update public.viagens
    set preco_confirmado_cliente = false, preco_recusado_em = now(), status = 'Preço recusado pela cliente'
    where id = v_id;
  end if;

  return query
  select v.id, c.nome, c.whatsapp, v.origem_endereco, v.destino_endereco, v.preco_cotado, p_aceita
  from public.viagens v
  left join public.clientes_transporte c on c.id = v.cliente_id
  where v.id = v_id;
end;
$$;

revoke execute on function public.confirmar_preco_cliente(bigint, text, boolean) from public, anon, authenticated;
grant execute on function public.confirmar_preco_cliente(bigint, text, boolean) to service_role;

-- ── Aceitar (atualizada): mesma função de
-- schema_oferta_apos_confirmacao_preco.sql, agora reconhecendo o status
-- novo. Sem isso a viagem ficaria presa em "Aguardando aceite de motorista"
-- mesmo depois de alguém aceitar, e o código de 4 dígitos de início não
-- seria gerado.
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
      status = case when status in ('Solicitada', 'Aguardando aceite de motorista') then 'Confirmada' else status end,
      codigo_inicio = case when status in ('Solicitada', 'Aguardando aceite de motorista') then lpad(floor(random() * 10000)::text, 4, '0') else codigo_inicio end
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
