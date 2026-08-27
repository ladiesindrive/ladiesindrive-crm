-- Go Ladies — módulo Peças (teste manual de intermediação/busca de autopeças)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente.

create table public.pecas_pedidos (
  id bigint generated always as identity primary key,
  peca text not null,
  carro text,
  cliente_nome text,
  cliente_whatsapp text,
  origem text,
  status text default 'Aberto',
  notas text,
  criado_em timestamptz default now()
);

create table public.pecas_tentativas (
  id bigint generated always as identity primary key,
  pedido_id bigint references public.pecas_pedidos(id) on delete cascade,
  loja_nome text,
  loja_contato text,
  tem_estoque text,
  valor numeric,
  prazo text,
  topou_comissao text,
  garantia text,
  observacao text,
  data_contato date,
  criado_em timestamptz default now()
);

alter table public.pecas_pedidos enable row level security;
alter table public.pecas_tentativas enable row level security;

create policy "Autenticados podem tudo - pecas_pedidos" on public.pecas_pedidos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - pecas_tentativas" on public.pecas_tentativas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Os 2 pedidos reais já em mãos (22/07/2026, grupo Mulheres V8)
insert into public.pecas_pedidos (peca, carro, origem, status) values
('Coxim superior do motor (lado direito)', 'Toyota RAV4 2007', 'Grupo Mulheres V8', 'Aberto'),
('Coluna elétrica (reparo ou nova)', 'Hyundai IX35', 'Grupo Mulheres V8', 'Aberto');
