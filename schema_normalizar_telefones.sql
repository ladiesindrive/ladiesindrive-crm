-- Ladies in Drive — Padroniza os números de contato já cadastrados pro
-- mesmo formato que o painel já aplica ao digitar: (DD) NNNNN-NNNN
-- (celular, 11 dígitos) ou (DD) NNNN-NNNN (fixo, 10 dígitos).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Seguro rodar mais de uma vez (idempotente). Números que não têm 10 ou 11
-- dígitos (depois de tirar DDI 55, se tiver) ficam como estavam, sem tentar
-- adivinhar o formato.

create or replace function public.fn_formatar_telefone_br(numero text)
returns text
language plpgsql
as $$
declare
  d text;
begin
  if numero is null then return null; end if;
  d := regexp_replace(numero, '\D', '', 'g');
  if length(d) in (12,13) and left(d,2) = '55' then
    d := substring(d from 3);
  end if;
  if length(d) = 11 then
    return '(' || substring(d,1,2) || ') ' || substring(d,3,5) || '-' || substring(d,8,4);
  elsif length(d) = 10 then
    return '(' || substring(d,1,2) || ') ' || substring(d,3,4) || '-' || substring(d,7,4);
  else
    return numero;
  end if;
end;
$$;

update public.leads set whatsapp = public.fn_formatar_telefone_br(whatsapp) where whatsapp is not null;
update public.motoristas set whatsapp = public.fn_formatar_telefone_br(whatsapp) where whatsapp is not null;
update public.clientes_transporte set whatsapp = public.fn_formatar_telefone_br(whatsapp) where whatsapp is not null;
update public.parceiro_contatos set numero = public.fn_formatar_telefone_br(numero) where numero is not null;
update public.pecas_pedidos set cliente_whatsapp = public.fn_formatar_telefone_br(cliente_whatsapp) where cliente_whatsapp is not null;
update public.candidatas set whatsapp = public.fn_formatar_telefone_br(whatsapp) where whatsapp is not null;
update public.vagas_candidatas set whatsapp = public.fn_formatar_telefone_br(whatsapp) where whatsapp is not null;

drop function public.fn_formatar_telefone_br(text);
