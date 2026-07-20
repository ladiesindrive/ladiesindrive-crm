-- Ladies in Drive — Módulo de Transporte (motoristas, clientes de viagem,
-- viagens, avaliações e pagamentos)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Não altera nenhuma tabela existente (leads, parceiros, orcamentos, candidatas).

create table public.motoristas (
  id bigint generated always as identity primary key,
  nome text not null,
  whatsapp text,
  email text,
  cnh_categoria text,
  cnh_ear boolean,
  cnh_validade date,
  antecedentes_data date,
  antecedentes_status text,
  regiao text,
  veiculo text,
  status text default 'Candidatura recebida',
  origem text,
  avaliacao_media numeric,
  criado_em timestamptz default now()
);

create table public.documentos_motorista (
  id bigint generated always as identity primary key,
  motorista_id bigint references public.motoristas(id) on delete cascade,
  tipo_documento text,
  validade date,
  status_verificacao text default 'Pendente',
  verificado_em date,
  verificado_por text,
  criado_em timestamptz default now()
);

create table public.clientes_transporte (
  id bigint generated always as identity primary key,
  nome text not null,
  whatsapp text,
  email text,
  regiao text,
  aniversario date,
  familiares text,
  segmento text,
  origem text,
  notas text,
  criado_em timestamptz default now()
);

create table public.viagens (
  id bigint generated always as identity primary key,
  cliente_id bigint references public.clientes_transporte(id) on delete set null,
  motorista_id bigint references public.motoristas(id) on delete set null,
  tipo_servico text,
  motorista_preferida boolean,
  canal_recepcao text,
  origem_endereco text,
  destino_endereco text,
  data_hora timestamptz,
  preco_cotado numeric,
  preco_final numeric,
  status text default 'Solicitada',
  preparacao_confirmada boolean default false,
  saida_confirmada boolean default false,
  grupo_whatsapp_criado boolean default false,
  link_acompanhamento text,
  criado_em timestamptz default now()
);

create table public.avaliacoes (
  id bigint generated always as identity primary key,
  viagem_id bigint references public.viagens(id) on delete cascade,
  nota_motorista numeric,
  nota_cliente numeric,
  comentario text,
  visivel boolean default false,
  criado_em timestamptz default now()
);

create table public.pagamentos_motorista (
  id bigint generated always as identity primary key,
  viagem_id bigint references public.viagens(id) on delete cascade,
  valor_repassado numeric,
  comissao_plataforma numeric,
  forma_pagamento text,
  status text default 'Pendente',
  data_pagamento date,
  notas text,
  criado_em timestamptz default now()
);

-- Segurança: só usuárias autenticadas (logadas) podem ler/escrever,
-- mesmo padrão já usado em leads/parceiros/orcamentos.
alter table public.motoristas enable row level security;
alter table public.documentos_motorista enable row level security;
alter table public.clientes_transporte enable row level security;
alter table public.viagens enable row level security;
alter table public.avaliacoes enable row level security;
alter table public.pagamentos_motorista enable row level security;

create policy "Autenticados podem tudo - motoristas" on public.motoristas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - documentos_motorista" on public.documentos_motorista
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - clientes_transporte" on public.clientes_transporte
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - viagens" on public.viagens
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - avaliacoes" on public.avaliacoes
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Autenticados podem tudo - pagamentos_motorista" on public.pagamentos_motorista
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Gatilho: toda candidatura de motorista feita pelo site (tabela
-- "candidatas", área de interesse = Motorista) cai automaticamente aqui
-- em "motoristas", já na primeira etapa do funil. Único ponto de
-- verdade, dois canais de entrada. Precisa ser SECURITY DEFINER porque
-- quem insere em "candidatas" é o papel anônimo (site sem login), que
-- não tem permissão de RLS em "motoristas".
create or replace function public.fn_candidata_para_motorista()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.area_interesse = 'Motorista' then
    insert into public.motoristas (nome, whatsapp, regiao, cnh_categoria, cnh_ear, veiculo, status, origem)
    values (new.nome, new.whatsapp, new.regiao, new.cnh_categoria, new.cnh_ear, new.veiculo_modelo, 'Candidatura recebida', 'Site');
  end if;
  return new;
end;
$$;

create trigger trg_candidata_para_motorista
  after insert on public.candidatas
  for each row
  execute function public.fn_candidata_para_motorista();
