-- Go Ladies — elimina a duplicação de Antecedentes Criminais (antes
-- rastreado tanto em motoristas.antecedentes_data/status quanto, às vezes,
-- também como uma linha solta em documentos_motorista). Passa a existir só
-- em documentos_motorista, junto com o novo tipo "Comprovante de Endereço".
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

-- Migra o que já estava preenchido nas colunas antigas, sem duplicar quem
-- já tinha uma linha de "Antecedentes Criminais" em documentos_motorista.
insert into public.documentos_motorista (motorista_id, tipo_documento, validade, status_verificacao)
select m.id, 'Antecedentes Criminais', m.antecedentes_data, nullif(m.antecedentes_status, '')
from public.motoristas m
where (m.antecedentes_data is not null or nullif(m.antecedentes_status, '') is not null)
  and not exists (
    select 1 from public.documentos_motorista dm
    where dm.motorista_id = m.id and dm.tipo_documento = 'Antecedentes Criminais'
  );

alter table public.motoristas
  drop column if exists antecedentes_data,
  drop column if exists antecedentes_status;
