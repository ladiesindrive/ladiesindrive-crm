-- Go Ladies — confirmação do preço com a cliente antes de oferecer a
-- viagem pras motoristas. Depois que você cota preço/tempo/km e muda o
-- status pra "Aguardando cliente confirmar preço", o n8n manda um WhatsApp
-- com botões pra cliente aceitar ou pedir ajuste. Se ela aceita, a viagem
-- volta pra "Solicitada" (agora liberada pra você chamar motoristas). Se
-- recusa, vai pra "Preço recusado pela cliente" pra você renegociar — nesse
-- momento nenhuma motorista ainda foi acionada, então não tem nada pra
-- desfazer do lado delas.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.viagens
  add column if not exists preco_confirmado_cliente boolean default false,
  add column if not exists preco_confirmacao_enviada_em timestamptz,
  add column if not exists preco_confirmado_em timestamptz,
  add column if not exists preco_recusado_em timestamptz;

-- ── Se você reabre a viagem em "Aguardando cliente confirmar preço" (seja
-- pela primeira vez, seja reenviando depois de ajustar o valor por causa de
-- uma recusa), zera o "enviada_em" pra o n8n pegar de novo no próximo
-- polling e mandar a mensagem — sem precisar de nenhum botão extra no CRM.
create or replace function public.fn_resetar_confirmacao_preco()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'Aguardando cliente confirmar preço'
     and (old.status is distinct from new.status or old.preco_cotado is distinct from new.preco_cotado) then
    new.preco_confirmacao_enviada_em := null;
    new.preco_confirmado_cliente := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_resetar_confirmacao_preco on public.viagens;

create trigger trg_resetar_confirmacao_preco
before update on public.viagens
for each row execute function public.fn_resetar_confirmacao_preco();

-- ── Chamada pelo n8n a cada poucos minutos: quais viagens estão devendo o
-- envio da confirmação de preço pra cliente agora.
create or replace function public.precos_aguardando_confirmacao()
returns table (
  viagem_id bigint,
  cliente_nome text,
  cliente_whatsapp text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  preco_cotado numeric
)
language sql
stable
as $$
  select v.id, c.nome, c.whatsapp, v.origem_endereco, v.destino_endereco,
         v.data, v.horario_partida, v.preco_cotado
  from public.viagens v
  join public.clientes_transporte c on c.id = v.cliente_id
  where v.status = 'Aguardando cliente confirmar preço'
    and v.preco_cotado is not null
    and v.preco_confirmacao_enviada_em is null
  order by v.criado_em;
$$;

revoke execute on function public.precos_aguardando_confirmacao() from public, anon, authenticated;
grant execute on function public.precos_aguardando_confirmacao() to service_role;

-- ── Chamada pelo n8n quando a cliente responde. Preferência é vir com
-- p_viagem_id (extraído do buttonId da resposta, ex: "preco_aceito:123" —
-- resolve na hora, sem ambiguidade mesmo se a mesma cliente tiver duas
-- viagens pendentes). Se a resposta não trouxer botão (texto solto), cai no
-- fallback por telefone, pegando a viagem pendente mais recente dela.
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
    set preco_confirmado_cliente = true, preco_confirmado_em = now(), status = 'Solicitada'
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

-- ── Chamada pelo n8n logo depois de mandar a mensagem, pra marcar que já
-- foi enviada (evita mandar de novo no próximo polling).
create or replace function public.marcar_confirmacao_preco_enviada(p_viagem_id bigint)
returns void
language sql
as $$
  update public.viagens
  set preco_confirmacao_enviada_em = now()
  where id = p_viagem_id;
$$;

revoke execute on function public.marcar_confirmacao_preco_enviada(bigint) from public, anon, authenticated;
grant execute on function public.marcar_confirmacao_preco_enviada(bigint) to service_role;
