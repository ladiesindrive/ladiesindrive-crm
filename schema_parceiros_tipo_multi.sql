-- Go Ladies — Tipo de parceria vira seleção múltipla
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- Antes: coluna só aceitava um valor (Mensalidade OU Patrocínio OU Embaixadora).
-- Depois: aceita combinações, guardadas como texto separado por vírgula (ex: "Mensalidade, Patrocínio"),
-- mesmo padrão já usado na coluna "categoria" desde a v03.
-- Não altera nenhuma linha existente (cada valor único atual continua válido, só sem a restrição).

alter table public.parceiros
  drop constraint if exists parceiros_tipo_parceria_check;
