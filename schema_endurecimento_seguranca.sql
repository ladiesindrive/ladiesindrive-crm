-- Go Ladies — endurecimento de segurança (achados da auditoria OWASP,
-- 21/08/2026). Rodar uma vez em: Supabase → SQL Editor → New query → colar
-- tudo → Run.

-- 1) Funções que só o n8n deveria chamar (com a service_role key, que
-- ignora RLS) hoje não têm nenhum `grant`/`revoke` explícito, então ficam
-- executáveis por PUBLIC (o que inclui anon/authenticated) por padrão do
-- Postgres. Elas não vazam dado hoje só "por acidente", porque a RLS de
-- outras tabelas ainda bloqueia — mas é melhor fechar isso de propósito.
revoke execute on function public.lembretes_pendentes() from public, anon, authenticated;
grant execute on function public.lembretes_pendentes() to service_role;

revoke execute on function public.confirmar_lembrete_por_telefone(text) from public, anon, authenticated;
grant execute on function public.confirmar_lembrete_por_telefone(text) to service_role;

revoke execute on function public.motoristas_disponiveis_proximas(double precision, double precision) from public, anon, authenticated;
grant execute on function public.motoristas_disponiveis_proximas(double precision, double precision) to service_role;

-- 2) Função órfã: o painel da motorista usa historico_ofertas_motorista()
-- (schema_motorista_painel_v2.sql) há tempos. Esta versão anterior não é
-- mais chamada por nenhum front-end, só reduz superfície de ataque à toa.
drop function if exists public.viagens_da_motorista();
