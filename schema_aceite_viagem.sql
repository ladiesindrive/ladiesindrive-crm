-- Ladies in Drive — permite oferecer uma viagem pra várias motoristas
-- candidatas (motorista_ids já suporta isso) e garante que só a PRIMEIRA
-- que clicar em "Aceitar" fica com a corrida, mesmo que duas cliquem ao
-- mesmo tempo — a trava é o próprio banco de dados (UPDATE com bloqueio de
-- linha), não depende de nada no navegador.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

alter table public.viagens
  add column if not exists motorista_id_confirmada bigint references public.motoristas(id);

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
  return v_linhas > 0;
end;
$$;

grant execute on function public.aceitar_viagem_motorista(bigint) to authenticated;
