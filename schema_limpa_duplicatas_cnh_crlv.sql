-- Ladies in Drive — CNH e CRLV passaram a ser documentos "sem histórico"
-- (uma linha só por motorista, atualizada a cada nova leitura), igual
-- Antecedentes/Comprovante de Endereço. Antes disso, cada leitura por IA
-- criava uma linha nova em documentos_motorista — este script apaga as
-- linhas antigas de CNH/CRLV, mantendo só a mais recente de cada uma por
-- motorista.
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run.

delete from public.documentos_motorista d
where d.tipo_documento in ('CNH', 'CRLV')
  and d.id <> (
    select max(d2.id) from public.documentos_motorista d2
    where d2.motorista_id = d.motorista_id and d2.tipo_documento = d.tipo_documento
  );
