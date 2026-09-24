# 8. Runbook: habilitar a Cloud API e colocar em produção

Este documento continua do ponto em que a [`04-fases-de-implementacao.md`](04-fases-de-implementacao.md) parou: o código das fases 1–4 está pronto, falta **habilitar o número na Cloud API** e **implantar a stack na VPS**. Ele é operacional — cada seção termina num estado verificável.

Ordem de execução:

1. [Diagnóstico](#1-diagnóstico-antes-de-mexer-em-qualquer-coisa): descobrir exatamente o que está bloqueando
2. [Escolher o caminho de habilitação](#2-por-que-a-api-não-habilita-e-os-três-caminhos) (é aqui que a maioria trava)
3. [Checklist de habilitação na Meta](#3-checklist-de-habilitação-na-meta)
4. [Subir a stack na VPS](#4-deploy-da-stack-na-vps)
5. [Conectar o número ao Chatwoot e o Agent Bot](#5-conectar-o-número-ao-chatwoot-e-ligar-o-agent-bot)
6. [Validação e go-live](#6-validação-e-go-live)
7. [Operação contínua](#7-operação-contínua)

---

## 1. Diagnóstico antes de mexer em qualquer coisa

O script [`scripts/diagnostico-whatsapp.sh`](../scripts/diagnostico-whatsapp.sh) consulta a Graph API e lista, em ordem, o que impede o número de funcionar. Por padrão ele **só lê** e não altera nada.

```bash
export WA_TOKEN="..."          # token permanente do System User (seção 3.2)
export WABA_ID="..."           # WhatsApp Manager → Configurações da conta
export PHONE_NUMBER_ID="..."   # opcional
./scripts/diagnostico-whatsapp.sh
```

Requisitos: `bash`, `curl`, `jq`. O token vai apenas no cabeçalho `Authorization` e não aparece na saída. Mesmo assim, revise a saída antes de colá-la em qualquer lugar. **Este repositório é público.**

O que ele verifica:

| Bloco | Verificação | Bloqueio típico |
|---|---|---|
| Token | validade, expiração, escopos, acesso à WABA | token temporário de 24h do painel; System User sem a WABA atribuída |
| WABA | revisão da conta, verificação do negócio, `health_status` | sem forma de pagamento; conta em revisão |
| Inscrição | `GET /{waba}/subscribed_apps` | lista vazia (Achado 1) |
| Número | `platform_type`, `status`, `name_status`, verificação, `health_status` | `NOT_APPLICABLE` (número não está na API), `PENDING` (falta registrar) |
| Templates | quantos aprovados | nenhum: só é possível responder dentro da janela de 24h |

Ações de escrita, só quando o diagnóstico pedir: `--inscrever`, `--registrar <PIN>`, `--teste 55DDDNUMERO`.

---

## 2. Por que a API "não habilita", e os três caminhos

### 2.1 A causa mais provável neste projeto

Os erros registrados no Achado 4 ([`05`](05-descobertas-coexistencia-whatsapp.md#55-achado-4--não-há-mecanismo-de-reconexão-manual-para-números-em-modo-de-coexistência-smb)) dão uma pista forte:

```
POST /{phone-number-id}/register     → "Register endpoint is not available for SMB businesses"
POST /{phone-number-id}/smb_app_data → "(#133010) Account not registered"
```

Isso indica um número que continua **registrado no app WhatsApp Business (SMB)** e foi apenas **vinculado ao portfólio** pelo Business Suite. A incorporação à Cloud API em modo de coexistência nunca foi concluída. O número aparece no WhatsApp Manager e pode até ficar `CONNECTED` de vez em quando, mas não está habilitado de fato para envio pela API. O diagnóstico confirma a hipótese quando mostra `platform_type: NOT_APPLICABLE` no número.

A razão é uma regra da Meta que não aparece no painel: **a coexistência (app + API no mesmo número) só pode ser ativada pelo fluxo *Embedded Signup*, e só por uma empresa *Tech Provider* ou *Solution Partner*.** Um desenvolvedor comum, com um app comum, não tem um botão para ativar coexistência no próprio número. Por isso nenhuma combinação de cliques no painel resolve.

Se o diagnóstico mostrar outra coisa (por exemplo `platform_type: CLOUD_API` com `status: PENDING`), o problema é outro e está na seção 3.

### 2.2 Os três caminhos

| | **A. Virar Tech Provider** | **B. Usar um BSP com coexistência** | **C. Número novo, só API** |
|---|---|---|---|
| Mantém o app no número atual | ✅ | ✅ | ❌ (o número atual segue só no app) |
| Tempo até funcionar | dias a semanas (verificação + revisão da Meta) | 1–2 dias | horas |
| Custo recorrente extra | nenhum | mensalidade do BSP | nenhum (um chip) |
| Mantém a arquitetura self-hosted (ADR-005) | ✅ | ⚠️ parcialmente, há um intermediário | ✅ |
| Serve para atender clientes terceiros ([`07`](07-modelo-de-servico.md)) | ✅ é pré-requisito | ⚠️ gera dependência do BSP | ❌ só números novos |
| Limitações de coexistência (seção 2.4) | sim | sim | nenhuma |

**Recomendação:** começar o **caminho A agora**, porque o modelo de serviço da seção 7 depende dele de qualquer forma: sem ser Tech Provider, a Nebula Host não consegue fazer implantação com coexistência para clientes. Enquanto a Meta analisa, o **caminho C** coloca o bot em produção em horas, se for aceitável divulgar um número novo, por exemplo "WhatsApp de suporte". Depois que A sair, o número principal entra em coexistência com a mesma stack. O Chatwoot aceita as duas inboxes em paralelo.

### 2.3 Caminho A, passo a passo

Os nomes dos menus mudam com frequência. Os passos abaixo refletem o fluxo em 2026.

1. **Identidade.** Entrar com a conta pessoal do Facebook, que deve ser **administradora** do portfólio empresarial da Nebula Host (Achado 6.1: nada de conta vinculada só ao Instagram).
2. **Verificação do negócio.** Configurações do negócio → Central de segurança → Verificação. Use documentos cujo nome e endereço batam **exatamente** com o portfólio e com o site. Sem essa verificação nada abaixo avança.
3. **App do tipo Business** com o produto WhatsApp, e com URL de política de privacidade, ícone e categoria preenchidos (necessários para publicar).
4. **Tornar-se Tech Provider.** No painel do app: WhatsApp → *Quickstart / Onboarding* → "Become a Tech Provider". Siga o checklist.
5. **Revisão do app (App Review)** para **acesso avançado** a `whatsapp_business_management` e `whatsapp_business_messaging`. A Meta pede um vídeo de tela mostrando o fluxo: o cliente clica, faz o Embedded Signup e depois envia e recebe uma mensagem. Grave o vídeo com o Chatwoot já rodando (seção 4).
6. **Facebook Login for Business → Configurações → criar configuração** com a variação *WhatsApp Embedded Signup*. Anote o **Configuration ID**.
7. **Embedded Signup v4.** A v2 é descontinuada em 8/out/2026; não implemente em cima dela. Para coexistência, o fluxo é iniciado com `featureType: "whatsapp_business_app_onboarding"`. O dono do número escaneia um QR code pelo app WhatsApp Business (versão ≥ 2.24.17) e escolhe se quer sincronizar o histórico.
8. **Nas 24h seguintes ao onboarding**, chamar `POST /{phone-number-id}/smb_app_data` duas vezes, com `sync_type: "smb_app_state_sync"` (contatos) e `sync_type: "history"` (histórico). Passado esse prazo, o erro `#133010` visto no Achado 4 volta a aparecer.
9. **Webhooks:** além de `messages`, assinar `smb_message_echoes` (mensagens enviadas pelo celular), `history` e `smb_app_state_sync`.
10. Rodar o diagnóstico: `platform_type: CLOUD_API`, `status: CONNECTED`.

**Atalho com o Chatwoot:** versões recentes do Chatwoot implementam o Embedded Signup. Basta preencher `WHATSAPP_APP_ID`, `WHATSAPP_APP_SECRET` e `WHATSAPP_CONFIGURATION_ID` (Super Admin → Configurações, ou `.env`) e a criação da inbox passa a abrir o fluxo da Meta. Antes de depender disso, confirme na versão instalada que o fluxo oferece a opção de conectar um número do app WhatsApp Business. Há relatos de falha silenciosa quando o *override* de webhook por número não é aplicado ([fazer-ai/chatwoot#568](https://github.com/fazer-ai/chatwoot/issues/568), [chatwoot discussion #13471](https://github.com/orgs/chatwoot/discussions/13471)). Depois do onboarding, confirme com o diagnóstico e com uma mensagem real.

### 2.4 Limitações da coexistência para conhecer antes

- **Abrir o app no celular pelo menos a cada ~13 dias**, senão a coexistência cai. Entra no checklist mensal do cliente.
- Throughput fixo de cerca de **20 mensagens/s**, somando app e API. Não é problema no porte-alvo.
- A primeira mensagem de cada contato pode não chegar ao webhook (Achado 2).
- Alguns recursos do app deixam de funcionar ou ficam limitados no número (por exemplo listas de transmissão e mensagens temporárias). Confira a lista atual na documentação da Meta antes de prometer algo ao cliente.
- Mensagens enviadas pelo celular chegam como `smb_message_echoes`. Se a versão do Chatwoot não tratar esse evento, elas **não aparecem** na conversa do Chatwoot, e o atendente vê só metade do diálogo. Teste isso na seção 6.

### 2.5 Caminho C, passo a passo (número novo)

1. Chip novo que **nunca** teve WhatsApp, ou teve a conta excluída pelo próprio app (Achado 6.3).
2. WhatsApp Manager → Números de telefone → Adicionar → verificar por SMS/voz → definir o nome de exibição (ele precisa bater com a marca e o site; "Nebula Host" funciona).
3. `./scripts/diagnostico-whatsapp.sh --registrar 123456`, trocando `123456` por um PIN de 6 dígitos que vocês escolhem e guardam no cofre de senhas. Esse PIN vira a verificação em duas etapas do número. O limite é de 10 tentativas a cada 72h.
4. Diagnóstico: `CLOUD_API` + `CONNECTED`. Pronto para a seção 5.

---

## 3. Checklist de habilitação na Meta

Estes itens valem para qualquer caminho. Os que o script não consegue verificar estão marcados com 👁.

### 3.1 Conta e app
- [ ] Conta do Facebook pessoal é admin do portfólio (Achado 6.1)
- [ ] Perfil do negócio completo: endereço, categoria, descrição e site (Achado 6.4: isso resolveu o erro de restrição por país)
- [ ] 👁 **App no modo Publicado (Live)**. Em modo de desenvolvimento, o app só recebe webhooks de teste disparados pelo painel e nunca mensagens reais. É a segunda causa mais comum de "configurei tudo e nada chega", depois do Achado 1
- [ ] 👁 **Forma de pagamento** na WABA (WhatsApp Manager → Configurações de pagamento). Sem ela, templates iniciados pela empresa falham com `131042`. Respostas dentro da janela de 24h aberta pelo cliente não são cobradas

### 3.2 Token permanente (nunca o temporário do painel)
1. Configurações do negócio → Usuários → **Usuários do sistema** → Adicionar (função Admin).
2. **Atribuir ativos**: o app (controle total) e a WABA (controle total).
3. **Gerar token**: selecionar o app, validade **Nunca** e os escopos `whatsapp_business_messaging` e `whatsapp_business_management` (mais `business_management` se o Chatwoot for fazer Embedded Signup).
4. Guardar no cofre de senhas. O token é mostrado uma única vez.

### 3.3 Webhook
- [ ] 👁 App → WhatsApp → Configuração → URL de callback (a do Chatwoot, seção 5) verificada
- [ ] 👁 Campo `messages` assinado (mais os campos de coexistência da seção 2.3, passo 9, quando for o caso)
- [ ] `subscribed_apps` com o app listado. Se não estiver: `--inscrever` (Achado 1)

### 3.4 Tabela de erros da Graph API

| Código | Significado | O que fazer |
|---|---|---|
| `190` | token expirado ou inválido | gerar token permanente (3.2) |
| `10`, `200` | sem permissão | System User sem o ativo atribuído ou sem o escopo |
| `100` + "not available for SMB" | número está no app e não na API | seção 2 |
| `133010` | conta não registrada | caminho C: `--registrar`; coexistência: refazer o Embedded Signup |
| `133005` | PIN de duas etapas errado | redefinir o PIN no WhatsApp Manager |
| `133016` | excesso de tentativas de registro | aguardar 72h |
| `131030` | destinatário fora da lista permitida | vocês estão usando o **número de teste** da Meta, não o real |
| `131047` | passou das 24h desde a última mensagem do cliente | enviar template aprovado |
| `132001` | template não existe (nome ou idioma) | conferir nome e `language.code` exatos |
| `131042` | problema de pagamento | forma de pagamento na WABA |
| `130497` | restrição por país | completar o perfil do negócio (Achado 6.4) |
| `131026` | não entregável | destinatário sem WhatsApp ou com versão antiga; não é problema da conta |
| `368` | bloqueio temporário por política | ver a qualidade do número no WhatsApp Manager |

---

## 4. Deploy da stack na VPS

A infraestrutura está em [`deploy/`](../deploy/): Chatwoot (rails + sidekiq), Postgres com pgvector, Redis e Caddy com HTTPS automático. O Agent Bot entra como serviço extra; o código dele não faz parte deste repositório público.

### 4.1 Pré-requisitos
- VPS com **pelo menos 4 GB de RAM e 2 vCPU** (o Chatwoot não roda estável com menos), Debian 12/13 ou Ubuntu 24.04
- Registro DNS `A` de `atendimento.seudominio.com.br` apontando para a VPS
- Portas 80 e 443 liberadas, e SSH só por chave
- Docker Engine e o plugin compose instalados

### 4.2 Subir

```bash
git clone https://github.com/DLL-P/nebula-host-whatsapp-bot.git && cd nebula-host-whatsapp-bot/deploy
cp .env.example .env
# preencher .env: domínio, e-mail e segredos
sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 24)/" .env
sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$(openssl rand -hex 24)/" .env
chmod 600 .env

docker compose pull
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d
docker compose logs -f rails   # aguarde "Listening on http://0.0.0.0:3000"
```

Abrir `https://atendimento.seudominio.com.br`. No primeiro acesso aparece o onboarding para criar a conta admin. Depois de criar, confirme que `ENABLE_ACCOUNT_SIGNUP=false` está no `.env`.

**Pronto quando:** HTTPS válido, login funcionando e `docker compose ps` com tudo `healthy`/`running`.

### 4.3 Agent Bot
1. Publicar a imagem do bot (registro privado) e descomentar o serviço `agent-bot` no `docker-compose.yml`. As variáveis dele ficam em `deploy/.env.bot`, que também está no `.gitignore`: chave da Claude API, URL e token do Chatwoot.
2. `docker compose up -d agent-bot`.

---

## 5. Conectar o número ao Chatwoot e ligar o Agent Bot

Pela ADR-003, o **Chatwoot é o dono do webhook da Meta**. Se o servidor Node das fases 1–3 ainda estiver cadastrado como URL de callback no app, ele será substituído. O app aceita uma única URL de callback.

**Caminho A com Embedded Signup no Chatwoot:** Configurações → Caixas de entrada → Adicionar → WhatsApp. O fluxo da Meta cuida de webhook e inscrição. Pule para o passo 4.

**Caminho C, ou inbox manual:**
1. Configurações → Caixas de entrada → Adicionar → WhatsApp → provedor **WhatsApp Cloud**. Informe o número em formato internacional (`+55...`), o Phone Number ID, o WABA ID e, como chave de API, o token permanente da seção 3.2.
2. Na inbox criada, em Configurações → Configuração, copie a **URL do webhook** (formato `https://<domínio>/webhooks/whatsapp/+55...`) e o **token de verificação**. Cole os dois no app da Meta → WhatsApp → Configuração → Webhook → Verificar e salvar. Assine `messages`.
3. `./scripts/diagnostico-whatsapp.sh --inscrever` (Achado 1: o Chatwoot não faz essa chamada na inbox manual).
4. **Agent Bot:** em `https://<domínio>/super_admin` → Agent Bots → New. Informe o nome e a URL de saída do bot (`http://agent-bot:3001/webhook` pela rede interna; se a versão do Chatwoot recusar endereços internos, use uma URL pública com HTTPS). Guarde o **access token** do bot.
5. Na inbox → Bot Configuration, selecione o bot. A partir daí, conversas novas nascem com status `pending` e o bot recebe `message_created`.
6. **Handoff:** quando o bot decidir encaminhar, ele chama `POST /api/v1/accounts/{account_id}/conversations/{id}/toggle_status` com `{"status":"open"}` (cabeçalho `api_access_token: <token do bot>`). A conversa sai da fila do bot e entra na fila humana.

---

## 6. Validação e go-live

Roteiro de teste com um celular que **não** seja o número comercial:

| # | Ação | Esperado |
|---|---|---|
| 1 | Diagnóstico completo | 0 bloqueios |
| 2 | Enviar "oi" | pode não chegar em coexistência (Achado 2). Envie uma segunda mensagem antes de concluir qualquer coisa |
| 3 | Enviar uma pergunta de FAQ ("qual o horário?") | resposta automática em poucos segundos; conversa visível no Chatwoot |
| 4 | Pedido complexo ("minha rede caiu, preciso de orçamento") | conversa muda para `open` com o rótulo de triagem e aparece na fila humana |
| 5 | Atendente responde pelo Chatwoot | resposta chega ao celular |
| 6 | *(coexistência)* responder pelo **app no celular do negócio** | a mensagem aparece também no Chatwoot. Se não aparecer, é o problema dos `smb_message_echoes` (seção 2.4) |
| 7 | `--teste 55DDDNUMERO` | template entregue (confirma a forma de pagamento) |
| 8 | Derrubar o agent-bot (`docker compose stop agent-bot`) e enviar uma mensagem | a conversa fica visível no Chatwoot para um humano; nada se perde |

Go-live: faça a virada em horário comercial, com alguém acompanhando a fila, e **nunca** remova o app do celular (Achado 6.2).

---

## 7. Operação contínua

Este é o conteúdo do componente de manutenção recorrente da seção [7.4](07-modelo-de-servico.md#74-dois-componentes-de-valor-comercial):

- **Monitoramento:** o diagnóstico devolve `exit 1` quando encontra bloqueios. Um cron a cada 15 minutos é suficiente para detectar problemas antes do cliente:
  ```cron
  */15 * * * * . /etc/nebula/wa.env && /opt/nebula/scripts/diagnostico-whatsapp.sh >/var/log/nebula/wa.log 2>&1 || /opt/nebula/alertar.sh
  ```
  Lembrete: em coexistência, um `DISCONNECTED` rápido é normal (Achado 3). Só vale alertar depois de 2–3 execuções seguidas com o mesmo estado.
- **Backup diário** do Postgres, mantido fora da VPS:
  `docker compose exec -T postgres pg_dump -U chatwoot chatwoot | gzip > backup-$(date +%F).sql.gz`
- **Atualizações:** fixar `CHATWOOT_VERSION` numa versão testada em vez de `latest`. Para atualizar: `pull`, depois `run --rm rails bundle exec rails db:migrate`, depois `up -d`.
- **Coexistência:** abrir o app no celular do negócio pelo menos a cada ~13 dias.
- **Versão da Graph API:** o script usa `v25.0` (sobrescreva com `GRAPH_VERSION`). A Meta desativa versões cerca de 2 anos após o lançamento. Revise uma vez por ano.
