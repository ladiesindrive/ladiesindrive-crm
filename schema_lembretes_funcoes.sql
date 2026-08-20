-- Ladies in Drive — funções de apoio pros workflows de n8n de lembrete de
-- viagem (1h/30min/15min antes da partida) e confirmação da motorista pelo
-- WhatsApp. Chamadas pelo n8n com a service_role key (bypassa RLS), nunca
-- pela chave pública do app — mesmo padrão de motoristas_disponiveis_proximas
-- em schema_app_publico.sql. Depende de schema_viagem_lembretes.sql já ter
-- rodado antes.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

-- ── O que está devendo alerta agora, com todo o texto pronto pro n8n
-- montar a mensagem (nome da motorista/cliente, whatsapp, endereços, valor).
-- Faixas largas (não um instante exato) porque o n8n roda a cada poucos
-- minutos, não o tempo todo — "not exists" garante que cada alerta só sai
-- uma vez, mesmo rodando de novo antes do próximo horário.
create or replace function public.lembretes_pendentes()
returns table (
  viagem_id bigint,
  tipo text,
  motorista_nome text,
  motorista_whatsapp text,
  cliente_nome text,
  cliente_whatsapp text,
  origem_endereco text,
  destino_endereco text,
  data date,
  horario_partida time,
  preco_motorista numeric
)
language sql
stable
as $$
  select
    v.id, t.tipo, m.nome, m.whatsapp, c.nome, c.whatsapp,
    v.origem_endereco, v.destino_endereco, v.data, v.horario_partida, v.preco_motorista
  from public.viagens v
  join public.motoristas m on m.id = v.motorista_id_confirmada
  left join public.clientes_transporte c on c.id = v.cliente_id
  cross join (values ('1h', 45, 70), ('30min', 20, 40), ('15min', 0, 20), ('atraso', -100000, -5)) as t(tipo, min_min, min_max)
  where v.status = 'Confirmada'
    and v.data is not null and v.horario_partida is not null
    and extract(epoch from ((v.data + v.horario_partida)::timestamp - now())) / 60 between t.min_min and t.min_max
    and not exists (select 1 from public.viagem_lembretes l where l.viagem_id = v.id and l.tipo = t.tipo)
  order by v.data, v.horario_partida;
$$;

-- ── Quando a motorista responde qualquer mensagem no WhatsApp depois do
-- alerta de 15 min, este é o número que respondeu — acha a viagem certa
-- (pelo telefone, comparando só os últimos 8 dígitos pra tolerar formatação
-- diferente), marca a saída como confirmada (igual ao botão "Confirmar
-- saída" do painel) e devolve os dados pro n8n avisar a cliente e a equipe.
create or replace function public.confirmar_lembrete_por_telefone(p_telefone text)
returns table (
  viagem_id bigint,
  motorista_nome text,
  cliente_nome text,
  cliente_whatsapp text,
  origem_endereco text,
  destino_endereco text
)
language plpgsql
as $$
declare
  v_viagem_id bigint;
begin
  select l.viagem_id into v_viagem_id
  from public.viagem_lembretes l
  join public.viagens v on v.id = l.viagem_id
  join public.motoristas m on m.id = v.motorista_id_confirmada
  where l.tipo = '15min' and l.confirmado = false
    and right(regexp_replace(m.whatsapp, '\D', '', 'g'), 8) = right(regexp_replace(p_telefone, '\D', '', 'g'), 8)
  order by l.enviado_em desc
  limit 1;

  if v_viagem_id is null then
    return;
  end if;

  update public.viagens
  set saida_confirmada = true, status = 'Em andamento'
  where id = v_viagem_id;

  update public.viagem_lembretes
  set confirmado = true, confirmado_em = now()
  where viagem_id = v_viagem_id and tipo = '15min';

  return query
  select v.id, m.nome, c.nome, c.whatsapp, v.origem_endereco, v.destino_endereco
  from public.viagens v
  join public.motoristas m on m.id = v.motorista_id_confirmada
  left join public.clientes_transporte c on c.id = v.cliente_id
  where v.id = v_viagem_id;
end;
$$;
