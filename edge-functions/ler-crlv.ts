// Ladies in Drive — Edge Function "ler-crlv"
// Lê uma foto ou PDF do CRLV (documento do carro) da motorista com IA
// (Claude) e devolve os dados prontos pra preencher o cadastro. Não salva
// nada sozinha — quem chama decide o que fazer com o resultado.
//
// COMO IMPLANTAR (primeira vez):
// 1. Supabase → seu projeto → Edge Functions → Create a new function
// 2. Nome da função: ler-crlv
// 3. Cole todo este arquivo no editor e clique em Deploy
// 4. Edge Functions → Secrets → confirme que ANTHROPIC_API_KEY já existe
//    (a mesma criada pra ler-cnh serve pras duas funções)
// 5. Confirme que "Verify JWT" está ligado nas configurações da função
//    (é o padrão) — assim só quem está logada no CRM consegue chamar.
// 6. Se já existia antes: cole este arquivo atualizado e clique em Deploy
//    de novo — a mudança só vale depois de reimplantar.

import Anthropic from "npm:@anthropic-ai/sdk";

// Só o painel do CRM chama essa function — restringe CORS a esses domínios
// em vez de aceitar qualquer origem.
const corsHeaders = {
  "Access-Control-Allow-Origin": "https://crm.ladiesindrive.com.br",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TIPOS_ACEITOS: Record<string, string> = {
  "image/jpeg": "image/jpeg",
  "image/png": "image/png",
  "image/webp": "image/webp",
  "application/pdf": "application/pdf",
};

const TAMANHO_MAXIMO_BYTES = 10 * 1024 * 1024; // 10MB

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
      throw new Error("Envie uma foto (JPG/PNG/WEBP) ou PDF do CRLV.");
    }
    if (arquivo.size > TAMANHO_MAXIMO_BYTES) {
      throw new Error("Arquivo muito grande (máximo 10MB).");
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
          name: "extrair_dados_crlv",
          description: "Registra os dados lidos no CRLV (Certificado de Registro e Licenciamento de Veículo).",
          strict: true,
          input_schema: {
            type: "object",
            properties: {
              placa: { type: "string", description: "Placa do veículo. Vazio se ilegível." },
              marca: { type: "string", description: "Marca do veículo, ex: 'Fiat'. Vazio se ilegível." },
              modelo: { type: "string", description: "Modelo do veículo, ex: 'Argo'. Vazio se ilegível." },
              ano_fabricacao: { type: "string", description: "Ano de fabricação. Vazio se ilegível." },
              ano_modelo: { type: "string", description: "Ano do modelo. Vazio se ilegível." },
              cor: { type: "string", description: "Cor predominante do veículo. Vazio se ilegível." },
              combustivel: { type: "string", description: "Combustível/motorização, ex: 'Flex', 'Diesel'. Vazio se ilegível." },
              renavam: { type: "string", description: "Número do RENAVAM. Vazio se ilegível." },
              chassi: { type: "string", description: "Número do chassi. Vazio se ilegível." },
              proprietario_nome: { type: "string", description: "Nome do proprietário impresso no documento. Vazio se ilegível." },
            },
            required: ["placa", "marca", "modelo", "ano_fabricacao", "ano_modelo", "cor", "combustivel", "renavam", "chassi", "proprietario_nome"],
            additionalProperties: false,
          },
        },
      ],
      tool_choice: { type: "tool", name: "extrair_dados_crlv" },
      messages: [
        {
          role: "user",
          content: [
            documentoBlock,
            { type: "text", text: "Extraia os dados deste CRLV (documento de veículo) brasileiro usando a ferramenta extrair_dados_crlv. Se algum campo não estiver legível ou não existir no documento, devolva string vazia." },
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
