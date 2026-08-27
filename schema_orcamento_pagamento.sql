-- Go Ladies — Pagamento direto no cadastro de Orçamento: forma de
-- pagamento, à vista/parcelado, se já foi pago, data prevista e data
-- realizada. Ao aceitar um orçamento, esses dados geram sozinhos a venda
-- e a(s) parcela(s) em Financeiro (sem precisar repetir na seção Vendas).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.orcamentos
  add column if not exists forma_pagamento text,
  add column if not exists parcelado boolean default false,
  add column if not exists num_parcelas integer default 1,
  add column if not exists pago boolean default false,
  add column if not exists data_prevista_pagamento date,
  add column if not exists data_realizada_pagamento date;

-- Liga a venda ao orçamento que a gerou, pra não duplicar a venda se o
-- orçamento for editado de novo depois de já Aceito.
alter table public.vendas
  add column if not exists orcamento_id bigint references public.orcamentos(id) on delete set null;
