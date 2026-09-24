#!/usr/bin/env bash
# Diagnóstico da habilitação de um número na WhatsApp Cloud API.
#
# Por padrão é SOMENTE LEITURA: consulta a Graph API e aponta, em ordem,
# o que impede o número de enviar/receber mensagens pela API.
# Ações de escrita só rodam com flag explícita (ver --help).
#
# Uso:
#   export WA_TOKEN="..."          # token permanente do System User
#   export WABA_ID="..."           # ID da conta do WhatsApp Business
#   export PHONE_NUMBER_ID="..."   # opcional: analisa só este número
#   ./scripts/diagnostico-whatsapp.sh
#
# O token é enviado apenas no cabeçalho Authorization e nunca é impresso.
# Mesmo assim, revise a saída antes de colá-la em qualquer lugar público.

set -uo pipefail

GRAPH_VERSION="${GRAPH_VERSION:-v25.0}"
GRAPH_BASE="${GRAPH_BASE:-https://graph.facebook.com}"
API="${GRAPH_BASE}/${GRAPH_VERSION}"

DO_SUBSCRIBE=0
REGISTER_PIN=""
TEST_TO=""
TEST_TEMPLATE="${TEST_TEMPLATE:-hello_world}"
TEST_LANG="${TEST_LANG:-en_US}"

usage() {
  cat <<'EOF'
Uso: diagnostico-whatsapp.sh [opções]

Variáveis de ambiente:
  WA_TOKEN          (obrigatória) token de acesso do System User
  WABA_ID           (obrigatória) ID da WhatsApp Business Account
  PHONE_NUMBER_ID   (opcional)    analisa só este número
  GRAPH_VERSION     (opcional)    padrão v25.0

Opções de escrita (nada é alterado sem elas):
  --inscrever           POST /{waba}/subscribed_apps (Achado 1)
  --registrar PIN       POST /{phone}/register com o PIN de 6 dígitos
                        (só para números NÃO coexistência; limite de 10/72h)
  --teste 55DDDNUMERO   envia o template $TEST_TEMPLATE ($TEST_LANG)
  -h, --help            mostra esta ajuda

Código de saída: 0 = nada bloqueando, 1 = bloqueios encontrados, 2 = uso.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --inscrever) DO_SUBSCRIBE=1 ;;
    --registrar) REGISTER_PIN="${2:-}"; shift ;;
    --teste) TEST_TO="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ -z "${WA_TOKEN:-}" ] || [ -z "${WABA_ID:-}" ]; then
  echo "Defina WA_TOKEN e WABA_ID antes de rodar." >&2
  usage >&2
  exit 2
fi
if [ -n "$REGISTER_PIN" ] && ! [[ "$REGISTER_PIN" =~ ^[0-9]{6}$ ]]; then
  echo "--registrar exige um PIN de 6 dígitos." >&2
  exit 2
fi
for bin in curl jq; do
  command -v "$bin" >/dev/null || { echo "Dependência ausente: $bin" >&2; exit 2; }
done

if [ -t 1 ]; then
  C_OK=$'\e[32m'; C_BAD=$'\e[31m'; C_WARN=$'\e[33m'; C_H=$'\e[1m'; C_0=$'\e[0m'
else
  C_OK=""; C_BAD=""; C_WARN=""; C_H=""; C_0=""
fi

PROBLEMS=()
ok()      { echo "  ${C_OK}✓${C_0} $*"; }
bad()     { echo "  ${C_BAD}✗${C_0} $*"; PROBLEMS+=("$*"); }
warn()    { echo "  ${C_WARN}!${C_0} $*"; }
info()    { echo "    $*"; }
section() { echo; echo "${C_H}== $* ==${C_0}"; }

# graph METHOD PATH [curl args...] -> imprime o JSON; retorna 1 se vier .error
graph() {
  local method="$1" path="$2"; shift 2
  local out
  out=$(curl -sS -X "$method" -H "Authorization: Bearer ${WA_TOKEN}" "$@" "${API}/${path}" 2>&1) || {
    printf '{"error":{"message":%s}}' "$(jq -Rn --arg m "$out" '$m')"
    return 1
  }
  printf '%s' "$out"
  jq -e 'has("error") | not' >/dev/null 2>&1 <<<"$out"
}

err_line() {
  jq -r '.error | "\(.message // "erro") (code \(.code // "?")\(if .error_subcode then "/" + (.error_subcode|tostring) else "" end))"' <<<"$1" 2>/dev/null || echo "$1"
}

# ---------------------------------------------------------------------------
section "1. Token de acesso"
APP_ID=""
if dbg=$(graph GET debug_token -G --data-urlencode "input_token=${WA_TOKEN}"); then
  d=$(jq '.data' <<<"$dbg")
  if [ "$(jq -r '.is_valid' <<<"$d")" = "true" ]; then ok "token válido"; else bad "token inválido ou revogado — gere um novo no System User"; fi
  APP_ID=$(jq -r '.app_id // empty' <<<"$d")
  info "app: $(jq -r '.application // "?"' <<<"$d") (id ${APP_ID:-?}) · tipo: $(jq -r '.type // "?"' <<<"$d")"
  exp=$(jq -r '.expires_at // 0' <<<"$d")
  if [ "$exp" = "0" ]; then ok "não expira (permanente)"
  else bad "token expira em $(date -d "@$exp" '+%d/%m/%Y %H:%M' 2>/dev/null || echo "$exp") — use token permanente de System User, não o temporário de 24h do painel"
  fi
  for s in whatsapp_business_messaging whatsapp_business_management; do
    if jq -e --arg s "$s" '.scopes // [] | index($s)' >/dev/null <<<"$d"; then ok "escopo $s"; else bad "falta o escopo $s"; fi
  done
  if jq -e '.granular_scopes' >/dev/null <<<"$d"; then
    if jq -e --arg w "$WABA_ID" '[.granular_scopes[] | select(.scope|startswith("whatsapp")) | (.target_ids // [])[]] | (length == 0) or (index($w) != null)' >/dev/null <<<"$d"; then
      ok "token alcança a WABA $WABA_ID"
    else
      bad "token não tem a WABA $WABA_ID entre os ativos — atribua a WABA ao System User (Configurações do negócio → Usuários do sistema → Atribuir ativos → controle total)"
    fi
  fi
else
  warn "não foi possível inspecionar o token: $(err_line "$dbg")"
fi

# ---------------------------------------------------------------------------
section "2. Conta do WhatsApp Business (WABA)"
if waba=$(graph GET "$WABA_ID" -G --data-urlencode "fields=id,name,account_review_status,currency,timezone_id"); then
  ok "WABA acessível: $(jq -r '.name' <<<"$waba")"
  rs=$(jq -r '.account_review_status // "?"' <<<"$waba")
  case "$rs" in
    APPROVED) ok "revisão da conta: APPROVED" ;;
    PENDING)  bad "revisão da conta: PENDING — aguarde a análise da Meta antes de enviar" ;;
    REJECTED) bad "revisão da conta: REJECTED — veja o motivo no WhatsApp Manager e peça nova análise" ;;
    *)        warn "revisão da conta: $rs" ;;
  esac
  info "moeda: $(jq -r '.currency // "?"' <<<"$waba") · fuso: $(jq -r '.timezone_id // "?"' <<<"$waba")"
else
  bad "WABA inacessível com este token: $(err_line "$waba")"
fi

if bv=$(graph GET "$WABA_ID" -G --data-urlencode "fields=business_verification_status"); then
  v=$(jq -r '.business_verification_status // "?"' <<<"$bv")
  if [ "$v" = "verified" ]; then ok "negócio verificado"
  else warn "verificação do negócio: $v — sem ela os limites de envio são menores e não é possível virar Tech Provider"
  fi
fi

if wh=$(graph GET "$WABA_ID" -G --data-urlencode "fields=health_status"); then
  jq -r '.health_status.entities[]? | select(.can_send_message != "AVAILABLE") | "\(.entity_type) \(.id): \(.can_send_message)", (.errors[]? | "      → [\(.error_code)] \(.error_description) | solução: \(.possible_solution // "-")")' <<<"$wh" \
    | while IFS= read -r l; do info "$l"; done
  if jq -e '.health_status.can_send_message == "AVAILABLE"' >/dev/null <<<"$wh"; then
    ok "health_status: pode enviar mensagens"
  else
    bad "health_status: $(jq -r '.health_status.can_send_message // "?"' <<<"$wh") (detalhes acima)"
  fi
fi

# ---------------------------------------------------------------------------
section "3. Inscrição da WABA no app (Achado 1)"
if subs=$(graph GET "${WABA_ID}/subscribed_apps"); then
  n=$(jq '.data | length' <<<"$subs")
  if [ "$n" -eq 0 ]; then
    bad "nenhum app inscrito na WABA — webhooks não chegam (rode com --inscrever)"
  else
    jq -r '.data[] | .whatsapp_business_api_data // . | "\(.name // "?") (id \(.id // "?"))"' <<<"$subs" | while IFS= read -r l; do info "inscrito: $l"; done
    if [ -n "$APP_ID" ] && ! jq -e --arg a "$APP_ID" '[.data[] | (.whatsapp_business_api_data.id // .id)] | index($a)' >/dev/null <<<"$subs"; then
      bad "o app do token ($APP_ID) não está entre os inscritos — rode com --inscrever"
    else
      ok "app inscrito"
    fi
  fi
else
  bad "falha ao ler subscribed_apps: $(err_line "$subs")"
fi

if [ "$DO_SUBSCRIBE" -eq 1 ]; then
  if r=$(graph POST "${WABA_ID}/subscribed_apps"); then ok "--inscrever: $(jq -c . <<<"$r")"
  else bad "--inscrever falhou: $(err_line "$r")"; fi
fi

# ---------------------------------------------------------------------------
section "4. Números de telefone"
PHONE_FIELDS="id,display_phone_number,verified_name,status,name_status,code_verification_status,platform_type,account_mode,quality_rating"
if [ -n "${PHONE_NUMBER_ID:-}" ]; then
  phones=$(graph GET "$PHONE_NUMBER_ID" -G --data-urlencode "fields=$PHONE_FIELDS") && phones=$(jq '{data: [.]}' <<<"$phones")
else
  phones=$(graph GET "${WABA_ID}/phone_numbers" -G --data-urlencode "fields=$PHONE_FIELDS")
fi
if jq -e '.error' >/dev/null <<<"$phones"; then
  bad "falha ao listar números: $(err_line "$phones")"
  phones='{"data":[]}'
fi
[ "$(jq '.data | length' <<<"$phones")" -eq 0 ] && bad "nenhum número encontrado nesta WABA"

while IFS= read -r p; do
  pid=$(jq -r '.id' <<<"$p")
  echo
  echo "  ${C_H}$(jq -r '.display_phone_number' <<<"$p") — $(jq -r '.verified_name // "?"' <<<"$p") (id $pid)${C_0}"

  coex=""
  if cx=$(graph GET "$pid" -G --data-urlencode "fields=is_on_biz_app"); then
    coex=$(jq -r '.is_on_biz_app // empty' <<<"$cx")
  fi
  pt=$(jq -r '.platform_type // "?"' <<<"$p")
  if [ "$coex" = "true" ]; then
    if [ "$pt" = "CLOUD_API" ]; then info "modo: COEXISTÊNCIA (app WhatsApp Business + API)"
    else info "número ativo no app WhatsApp Business (is_on_biz_app=true)"; fi
  fi
  case "$pt" in
    CLOUD_API) ok "platform_type: CLOUD_API" ;;
    NOT_APPLICABLE)
      bad "platform_type: NOT_APPLICABLE — o número está só vinculado ao portfólio (app WhatsApp Business), não foi incorporado à Cloud API. Ver docs/08, seção 2" ;;
    ON_PREMISE) bad "platform_type: ON_PREMISE — API local descontinuada; migre para Cloud API" ;;
    *) warn "platform_type: $pt" ;;
  esac

  st=$(jq -r '.status // "?"' <<<"$p")
  case "$st" in
    CONNECTED) ok "status: CONNECTED" ;;
    PENDING)
      if [ "$coex" = "true" ]; then bad "status: PENDING em número de coexistência — conclua o Embedded Signup (não há /register para SMB)"
      else bad "status: PENDING — falta registrar: --registrar <PIN de 6 dígitos>"; fi ;;
    DISCONNECTED)
      if [ "$coex" = "true" ]; then warn "status: DISCONNECTED — em coexistência costuma voltar sozinho (Achado 3); abra o app no celular e aguarde"
      else bad "status: DISCONNECTED — registre de novo com --registrar <PIN>"; fi ;;
    *) bad "status: $st — verifique o WhatsApp Manager (restrição, banimento ou revisão)" ;;
  esac

  ns=$(jq -r '.name_status // "?"' <<<"$p")
  case "$ns" in
    APPROVED|AVAILABLE_WITHOUT_REVIEW) ok "nome de exibição: $ns" ;;
    PENDING_REVIEW) warn "nome de exibição em análise (PENDING_REVIEW)" ;;
    DECLINED) bad "nome de exibição RECUSADO — ajuste para bater com a marca/site e reenvie" ;;
    *) warn "nome de exibição: $ns" ;;
  esac

  cv=$(jq -r '.code_verification_status // "?"' <<<"$p")
  case "$cv" in
    VERIFIED) ok "posse do número verificada" ;;
    *) if [ "$coex" = "true" ]; then info "code_verification_status: $cv (normal em coexistência)"
       else bad "code_verification_status: $cv — verifique o número por SMS/voz no WhatsApp Manager"; fi ;;
  esac

  am=$(jq -r '.account_mode // "?"' <<<"$p")
  [ "$am" = "LIVE" ] && ok "account_mode: LIVE" || warn "account_mode: $am (número de teste/sandbox?)"
  info "qualidade: $(jq -r '.quality_rating // "?"' <<<"$p")"

  if ph=$(graph GET "$pid" -G --data-urlencode "fields=health_status"); then
    if jq -e '.health_status.can_send_message == "AVAILABLE"' >/dev/null <<<"$ph"; then
      ok "health_status do número: pode enviar"
    else
      bad "health_status do número: $(jq -r '.health_status.can_send_message // "?"' <<<"$ph")"
      jq -r '.health_status.entities[]?.errors[]? | "      → [\(.error_code)] \(.error_description) | solução: \(.possible_solution // "-")"' <<<"$ph" \
        | while IFS= read -r l; do info "$l"; done
    fi
  fi
done < <(jq -c '.data[]' <<<"$phones")

if [ -n "$REGISTER_PIN" ]; then
  target="${PHONE_NUMBER_ID:-$(jq -r '.data[0].id // empty' <<<"$phones")}"
  if [ -z "$target" ]; then bad "--registrar: nenhum número para registrar"
  elif r=$(graph POST "${target}/register" -H "Content-Type: application/json" \
          --data "{\"messaging_product\":\"whatsapp\",\"pin\":\"${REGISTER_PIN}\"}"); then
    ok "--registrar: $(jq -c . <<<"$r")"
  else
    bad "--registrar falhou: $(err_line "$r")"
  fi
fi

# ---------------------------------------------------------------------------
section "5. Templates de mensagem"
if tpl=$(graph GET "${WABA_ID}/message_templates" -G --data-urlencode "fields=name,status,language" --data-urlencode "limit=100"); then
  appr=$(jq '[.data[] | select(.status=="APPROVED")] | length' <<<"$tpl")
  info "$(jq '.data | length' <<<"$tpl") template(s), $appr aprovado(s)"
  jq -r '.data[] | "      \(.name) [\(.language)] \(.status)"' <<<"$tpl" | head -20
  [ "$appr" -eq 0 ] && warn "sem template aprovado: só dá para responder dentro da janela de 24h aberta pelo cliente"
else
  warn "falha ao listar templates: $(err_line "$tpl")"
fi

if [ -n "$TEST_TO" ]; then
  section "Envio de teste"
  target="${PHONE_NUMBER_ID:-$(jq -r '.data[0].id // empty' <<<"$phones")}"
  body=$(jq -nc --arg to "$TEST_TO" --arg t "$TEST_TEMPLATE" --arg l "$TEST_LANG" \
    '{messaging_product:"whatsapp",to:$to,type:"template",template:{name:$t,language:{code:$l}}}')
  if r=$(graph POST "${target}/messages" -H "Content-Type: application/json" --data "$body"); then
    ok "mensagem aceita pela API: $(jq -r '.messages[0].id // "?"' <<<"$r")"
    info "aceita ≠ entregue: confira o status (sent/delivered/failed) no webhook"
  else
    bad "envio falhou: $(err_line "$r") — consulte a tabela de erros em docs/08"
  fi
fi

# ---------------------------------------------------------------------------
section "Resumo"
echo "  Itens que o script não enxerga (confira à mão):"
echo "    - app no modo Publicado/Live (painel do app, topo da página)"
echo "    - forma de pagamento na WABA (WhatsApp Manager → Configurações de pagamento)"
echo "    - URL de callback do webhook verificada e campo 'messages' assinado"
echo
if [ "${#PROBLEMS[@]}" -eq 0 ]; then
  echo "  ${C_OK}Nenhum bloqueio encontrado.${C_0}"
  exit 0
fi
echo "  ${C_BAD}${#PROBLEMS[@]} bloqueio(s), na ordem em que aparecem:${C_0}"
i=1
for p in "${PROBLEMS[@]}"; do echo "    $i. $p"; i=$((i+1)); done
exit 1
