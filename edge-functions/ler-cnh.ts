// Ladies in Drive — Edge Function "ler-cnh"
// Lê uma foto ou PDF da CNH da motorista com IA (Claude) e devolve os dados
// prontos pra preencher o cadastro. Não salva nada sozinha — quem chama
// decide o que fazer com o resultado.
//
// COMO IMPLANTAR (primeira vez):
// 1. Supabase → seu projeto → Edge Functions → Create a new function
// 2. Nome da função: ler-cnh
// 3. Cole todo este arquivo no editor e clique em Deploy
// 4. Edge Functions → Secrets → adicione ANTHROPIC_API_KEY com a chave
//    (console.anthropic.com → API Keys → Create Key)
// 5. Confirme que "Verify JWT" está ligado nas configurações da função
//    (é o padrão) — assim só quem está logada no CRM consegue chamar.

import Anthropic from "npm:@anthropic-ai/sdk";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TIPOS_ACEITOS: Record<string, string> = {
  "image/jpeg": "image/jpeg",
  "image/png": "image/png",
  "image/webp": "image/webp",
  "application/pdf": "application/pdf",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const formData = await req.formData();
    const arquivo = formData.get("arquivo");
    if (!(arquivo instanceof File)) {
      throw new Error("Nenhum arquivo enviado.");
    }
    const mediaType = TIPOS_ACEITOS[arquivo.type];
    if (!mediaType) {
      throw new Error("Envie uma foto (JPG/PNG/WEBP) ou PDF da CNH.");
    }

    const bytes = new Uint8Array(await arquivo.arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const base64 = btoa(binary);

    const documentoBlock = mediaType === "application/pdf"
      ? { type: "document" as const, source: { type: "base64" as const, media_type: mediaType, data: base64 } }
      : { type: "image" as const, source: { type: "base64" as const, media_type: mediaType, data: base64 } };

    const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    const response = await client.messages.create({
      model: "claude-opus-5",
      max_tokens: 1500,
      thinking: { type: "adaptive" },
      output_config: { effort: "low" },
      tools: [
        {
          name: "extrair_dados_cnh",
          description: "Registra os dados lidos na Carteira Nacional de Habilitação (CNH).",
          strict: true,
          input_schema: {
            type: "object",
            properties: {
              nome_completo: { type: "string", description: "Nome completo do condutor, como impresso no documento. Vazio se ilegível." },
              cpf: { type: "string", description: "CPF como impresso (com pontuação se houver). Vazio se ilegível." },
              numero_registro: { type: "string", description: "Número de registro da CNH. Vazio se ilegível." },
              categoria: { type: "string", description: "Categoria da habilitação. Use o campo rotulado 'CAT HAB' (ou 'Categoria') na frente do documento — NÃO use o campo 'ACC', que é outra informação. Se o verso do documento também estiver na imagem, confira a grade de categorias (colunas 9-12): a(s) categoria(s) com uma data preenchida na linha são as válidas, use isso pra confirmar ou corrigir o que leu na frente. Ex: 'B', 'AB', 'D'. Vazio se ilegível." },
              validade: { type: "string", description: "Data de validade no formato AAAA-MM-DD. Vazio se ilegível." },
              tem_ear: { type: "boolean", description: "true se o campo de observações do documento contém 'EAR' (Exerce Atividade Remunerada), false se as observações estão visíveis e não contêm EAR, null se não foi possível ler o campo de observações." },
            },
            required: ["nome_completo", "cpf", "numero_registro", "categoria", "validade", "tem_ear"],
            additionalProperties: false,
          },
        },
      ],
      tool_choice: { type: "tool", name: "extrair_dados_cnh" },
      messages: [
        {
          role: "user",
          content: [
            documentoBlock,
            { type: "text", text: "Extraia os dados desta CNH (Carteira Nacional de Habilitação) brasileira usando a ferramenta extrair_dados_cnh. Se algum campo não estiver legível ou não existir no documento, devolva string vazia (ou null em tem_ear)." },
          ],
        },
      ],
    });

    const toolUse = response.content.find((b) => b.type === "tool_use");
    if (!toolUse || toolUse.type !== "tool_use") {
      throw new Error("A IA não conseguiu ler o documento. Tente outra foto.");
    }

    return new Response(JSON.stringify({ dados: toolUse.input }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
