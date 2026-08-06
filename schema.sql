-- Ladies in Drive CRM — schema inicial (Supabase / Postgres)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run

create table public.leads (
  id bigint generated always as identity primary key,
  exemplo boolean default false,
  nome text not null,
  whatsapp text,
  email text,
  bairro text,
  cidade text,
  estado text,
  categoria text,
  servico text,
  veiculo text,
  urgencia text,
  descricao text,
  etapa text default 'Novo lead',
  origem text,
  data date,
  responsavel text,
  notas text,
  criado_em timestamptz default now()
);

create table public.parceiros (
  id bigint generated always as identity primary key,
  exemplo boolean default false,
  nome text not null,
  categoria text,
  regiao text,
  selo text,
  status text,
  contato text,
  comissao text,
  notas text,
  criado_em timestamptz default now()
);

create table public.orcamentos (
  id bigint generated always as identity primary key,
  exemplo boolean default false,
  lead_id bigint references public.leads(id) on delete set null,
  servico text,
  parceiro_id bigint references public.parceiros(id) on delete set null,
  valor_cotado numeric,
  valor_final numeric,
  status text,
  data date,
  criado_em timestamptz default now()
);

-- Segurança: só usuárias autenticadas (logadas) podem ler/escrever
alter table public.leads enable row level security;
alter table public.parceiros enable row level security;
alter table public.orcamentos enable row level security;

create policy "Autenticados podem tudo - leads" on public.leads
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - parceiros" on public.parceiros
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - orcamentos" on public.orcamentos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Dados de exemplo (os mesmos do protótipo), pra não abrir vazio
insert into public.leads (exemplo, nome, whatsapp, email, bairro, cidade, estado, categoria, servico, veiculo, urgencia, descricao, etapa, origem, data, responsavel, notas) values
(true,'Camila Rodrigues','51 99999-0001','','Petrópolis','Porto Alegre','RS','SOS e Emergências','Guincho e Reboque 24h','Hatch','Urgente','Carro não liga na garagem do trabalho.','Fechado - Ganho','Instagram','2026-06-20','Jú',''),
(true,'Fernanda Alves','51 99999-0002','','Menino Deus','Porto Alegre','RS','Manutenção e Prevenção','Oficina Mecânica Geral','Sedan','Essa semana','Barulho estranho no motor.','Orçamento enviado','Indicação','2026-06-28','Jú',''),
(true,'Bianca Souza','51 99999-0003','bianca@email.com','Moinhos de Vento','Porto Alegre','RS','Proteção, Compra e Burocracia','Consultoria de Compra e Venda (Car Hunter)','SUV','Sem pressa','Quer ajuda pra escolher um SUV até 90 mil.','Negociação','Google','2026-07-01','Jú',''),
(true,'Renata Lima','51 99999-0004','','Cidade Baixa','Porto Alegre','RS','Viagem','Viagem sob demanda','-','Essa semana','Viagem até o aeroporto na sexta.','Novo lead','Facebook','2026-07-03','Jú','');

insert into public.parceiros (exemplo, nome, categoria, regiao, selo, status, contato, comissao, notas) values
(true,'Oficina do Marcelo','Oficina mecânica','Zona Sul - POA','sim','Ativo','51 98888-1111','10%',''),
(true,'Guincho Express','Guincho','Grande POA','sim','Ativo','51 98888-2222','Fixo por acionamento',''),
(true,'Seguros Confiança','Seguradora','RS','nao','Em análise','51 98888-3333','A combinar','Aguardando contrato de parceria');

insert into public.orcamentos (exemplo, lead_id, servico, parceiro_id, valor_cotado, valor_final, status, data) values
(true, (select id from public.leads where nome='Camila Rodrigues' limit 1), 'Guincho e Reboque 24h', (select id from public.parceiros where nome='Guincho Express' limit 1), 180, 180, 'Aceito', '2026-06-20'),
(true, (select id from public.leads where nome='Fernanda Alves' limit 1), 'Oficina Mecânica Geral', (select id from public.parceiros where nome='Oficina do Marcelo' limit 1), 650, null, 'Enviado', '2026-06-29');
