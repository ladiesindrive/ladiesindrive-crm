-- Go Ladies — fix de fuso horário em ofertas_aguardando_aviso().
--
-- Incidente de 02/09/2026: viagem #27 (data 2026-09-02, horário 22:30)
-- ficou com as duas ofertas de motorista (Juliana e Rafaela) liberadas
-- e paradas — o aviso_tentativas nunca subiu, o workflow "Avisar
-- Motorista de Oferta Nova" rodava a cada 3min sem erro mas devolvia
-- zero linhas. Causa: a condição "v.data >= current_date" usa o fuso do
-- banco (UTC no Supabase). Depois das 21h em Brasília (UTC-3) o
-- current_date do Postgres já virou o dia seguinte, então uma viagem
-- "hoje" (2026-09-02, horário local) passa a comparar contra
-- current_date = 2026-09-03 e falha silenciosamente. Mesma classe de
-- bug do schema_fix_fuso_lembretes.sql, função diferente (essa não
-- tinha sido corrigida na época porque só existia depois, ver
-- schema_oferta_apos_confirmacao_preco.sql / schema_limite_reenvio_whatsapp.sql).
--
-- Rodar em: Supabase → SQL Editor → New query → colar tudo → Run.
-- Seguro rodar de novo se rodar por engano (create or replace).

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
as $$
  with alvo as (
    update public.viagem_ofertas o
    set aviso_tentativas = o.aviso_tentativas + 1
    where o.desfecho = 'Pendente'
      and o.avisada_em is null
      and o.aviso_tentativas < 3
      and exists (
        select 1 from public.viagens v
        where v.id = o.viagem_id
          and v.motorista_id_confirmada is null
          and (v.data is null or v.data >= (now() at time zone 'America/Sao_Paulo')::date)
          and public.oferta_liberada_para_motoristas(v.status, v.preco_cotado, v.preco_confirmado_cliente)
      )
    returning o.id, o.viagem_id, o.motorista_id
  )
  select a.id, a.viagem_id, m.nome, m.whatsapp,
         v.origem_endereco, v.destino_endereco, v.data, v.horario_partida,
         v.distancia_km, v.duracao_prevista_min, v.preco_motorista
  from alvo a
  join public.viagens v on v.id = a.viagem_id
  join public.motoristas m on m.id = a.motorista_id
  where m.whatsapp is not null;
$$;

revoke execute on function public.ofertas_aguardando_aviso() from public, anon, authenticated;
grant execute on function public.ofertas_aguardando_aviso() to service_role;
