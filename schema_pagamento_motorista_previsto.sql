-- Go Ladies — data prevista de pagamento e link do comprovante no
-- repasse à motorista. Antes só existia data_pagamento (a realizada).
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

alter table public.pagamentos_motorista
  add column if not exists data_prevista_pagamento date,
  add column if not exists comprovante_url text;
