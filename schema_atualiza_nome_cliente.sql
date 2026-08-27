-- Go Ladies — corrige registrar_pedido_viagem: quando o WhatsApp já
-- tem cadastro, a função reaproveitava o cliente existente mas nunca
-- atualizava o nome. Resultado: um teste antigo com nome errado (ex:
-- "teste 1") ficava "grudado" no cliente pra sempre, mesmo enviando o
-- formulário de novo com o nome certo.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

create or replace function public.registrar_pedido_viagem(
  p_nome text,
  p_whatsapp text,
  p_tipo_servico text,
  p_origem text,
  p_destino text,
  p_data date,
  p_horario time,
  p_data_retorno date default null,
  p_horario_retorno time default null,
  p_origem_retorno text default null,
  p_destino_retorno text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cliente_id bigint;
  v_token uuid;
begin
  select id into v_cliente_id from public.clientes_transporte where whatsapp = p_whatsapp limit 1;

  if v_cliente_id is null then
    insert into public.clientes_transporte (nome, whatsapp, origem)
    values (p_nome, p_whatsapp, 'Site')
    returning id into v_cliente_id;
  else
    update public.clientes_transporte set nome = p_nome where id = v_cliente_id;
  end if;

  insert into public.viagens (
    cliente_id, tipo_servico, canal_recepcao, origem_endereco, destino_endereco,
    data, horario_partida, data_retorno, horario_retorno,
    origem_retorno_endereco, destino_retorno_endereco, status
  )
  values (
    v_cliente_id, p_tipo_servico, 'Site', p_origem, p_destino,
    p_data, p_horario, p_data_retorno, p_horario_retorno,
    p_origem_retorno, p_destino_retorno, 'Solicitada'
  )
  returning tracking_token into v_token;

  return v_token;
end;
$$;
