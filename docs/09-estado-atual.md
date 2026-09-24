# 9. Estado atual da implantação

> Atualizado em 24/09/2026. Este arquivo registra onde a implantação parou e o que vem a seguir. Atualize-o a cada avanço.
> Identificadores de conta (IDs, tokens) **não** entram aqui porque o repositório é público. Eles ficam na cópia privada (ver "Onde está salvo").

## Diagnóstico confirmado no Business Manager

O portfólio **Nebula Flux Soluções** tem:

| Item | Situação |
|---|---|
| App de desenvolvedor **Nebula Flux Atendimento** | pertence ao portfólio ✅ |
| Usuário do sistema **nebulaflux-bot** | existe, com acesso total ao app ✅. Falta confirmar se tem a conta do WhatsApp atribuída |
| Conta WhatsApp **"Nebula Host" (Aplicativo WhatsApp Business)** | contém o **número principal**, status **Offline** |
| Conta WhatsApp **"Nebula Host"** (sem rótulo) | **vazia**, pronta para receber um número pela Cloud API |
| Test WhatsApp Business Account | conta de teste da Meta, ignorar |
| Verificação da empresa | **em andamento** |

**Conclusão:** o número principal está apenas **vinculado como app WhatsApp Business (SMB)**. Por isso a API não habilita e o `/register` falha. Nenhum ajuste no painel resolve isso (ver [`08`](08-habilitacao-e-producao.md), seção 2.1).

## Decisão tomada

Fazer os **dois caminhos em paralelo**:

- **Opção 1 (caminho C do runbook):** número novo (chip que nunca teve WhatsApp) na conta vazia, direto na Cloud API. Coloca o bot no ar em horas e gera o ambiente para gravar o vídeo da revisão da Meta.
- **Opção 2 (caminho A do runbook), a principal:** tornar a empresa **Tech Provider** e colocar o número principal em **coexistência** via Embedded Signup.

## Próximos passos

### Pendências sem chip (podem ser feitas a qualquer momento)
- [ ] Conta vazia "Nebula Host" → Summary → Edit: endereço, moeda **BRL**, fuso **America/Sao_Paulo**
- [ ] WhatsApp Manager → forma de pagamento
- [ ] Confirmar o nome oficial no CNPJ ("Nebula Flux Soluções" ou "Nebula Host") e alinhar portfólio, site e documentos
- [ ] Usuário do sistema nebulaflux-bot → atribuir as contas do WhatsApp (controle total) → gerar **token permanente** (validade "Nunca", escopos `whatsapp_business_messaging` e `whatsapp_business_management`) → guardar no gerenciador de senhas

### Opção 1: chip novo
- [ ] Comprar o chip (pré-pago serve; **nunca** usar número virtual ou de SMS grátis)
- [ ] Conta vazia → Adicionar telefone → nome "Nebula Host", categoria Serviços de TI → código por SMS
- [ ] `./scripts/diagnostico-whatsapp.sh --registrar <PIN de 6 dígitos>` (guardar o PIN)
- [ ] Diagnóstico sem bloqueios (`CLOUD_API` + `CONNECTED`)
- [ ] Subir a stack de `deploy/` na VPS, criar a inbox e ligar o Agent Bot (runbook, seções 4 e 5)
- [ ] Roteiro de testes (runbook, seção 6)

### Opção 2: Tech Provider + coexistência no número principal
- [ ] Concluir a verificação da empresa (Central de segurança)
- [ ] App: política de privacidade, ícone, categoria → modo **Live**
- [ ] Tornar-se Tech Provider e passar pela revisão do app (acesso avançado aos dois escopos), com vídeo gravado no Chatwoot da opção 1
- [ ] Configuração do Facebook Login for Business (Embedded Signup **v4**)
- [ ] Embedded Signup com o QR do celular do número principal; `smb_app_data` nas 24h seguintes
- [ ] Assinar os webhooks `messages`, `smb_message_echoes`, `history` e `smb_app_state_sync`

## Não fazer ⚠️
- **Não** adicionar o número principal à conta vazia, **não** remover o app do celular e **não** excluir a conta "Aplicativo WhatsApp Business". Isso derrubou o atendimento antes (Achado 6.2).
- **Não** usar plataformas não oficiais (Z-API, Evolution, Baileys etc.), por risco de banimento (ADR-001).
- **Não** colar tokens neste repositório.

## Ambiente de trabalho
- As sessões do Claude Code com acesso ao navegador e ao terminal rodam no **servidor Debian do homelab** (usuário `dll`). Para retomar: `cd ~/cyberresearch && ~/.local/bin/claude --resume`, depois `/remote-control` para usar pelo app.
- Clone deste repositório no servidor: `~/nebula-host-whatsapp-bot` (branch `claude/bold-keller-jm54dk`).
- Sessões do Claude na nuvem (claude.ai/code) **não** alcançam o servidor nem o navegador. Elas servem para documentação e código, que chegam ao servidor via GitHub.

## Onde está salvo
- **GitHub:** este repositório, branch `claude/bold-keller-jm54dk` (versão sem IDs)
- **Google Drive:** documento "Nebula Host – WhatsApp API – Estado atual" (versão privada, com IDs)
- **Servidor:** clone do repositório + cópia no HD dedicado
