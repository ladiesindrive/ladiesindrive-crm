-- Go Ladies — Situação do EAR vira texto (era boolean)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Antes: cnh_ear só guardava sim/não (true/false).
-- Depois: guarda o texto exato usado no site e no CRM ("Já tenho EAR",
-- "Não tenho EAR" ou "Estou em processo"), pra ter a opção "em processo"
-- que o boolean não conseguia representar.
-- Seguro rodar mais de uma vez: só altera a coluna se ainda for boolean.
-- Dados existentes: true vira "Já tenho EAR", false/nulo vira nulo.

do $$
begin
  if (select data_type from information_schema.columns
      where table_schema='public' and table_name='motoristas' and column_name='cnh_ear') = 'boolean' then
    alter table public.motoristas
      alter column cnh_ear type text using (case when cnh_ear then 'Já tenho EAR' else null end);
  end if;

  if (select data_type from information_schema.columns
      where table_schema='public' and table_name='candidatas' and column_name='cnh_ear') = 'boolean' then
    alter table public.candidatas
      alter column cnh_ear type text using (case when cnh_ear then 'Já tenho EAR' else null end);
  end if;
end $$;
