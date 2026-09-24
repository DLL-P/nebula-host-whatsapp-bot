# Contexto para o Claude

Projeto: chatbot de atendimento WhatsApp da Nebula Host (portfólio Meta "Nebula Flux Soluções").
Stack: WhatsApp Cloud API → Chatwoot (self-hosted) → Agent Bot em Node.js com Claude Haiku. Ver README e docs/.

**Antes de qualquer coisa, leia `docs/09-estado-atual.md`**: é onde a implantação parou, o que foi decidido e os próximos passos. Atualize esse arquivo sempre que algo avançar.

Regras do projeto:
- Repositório **público**: nunca versionar tokens, IDs de conta (WABA, app, número) nem o `.env`. IDs ficam na cópia privada (Google Drive / HD do servidor).
- Nunca sugerir remover o app WhatsApp do celular do número principal nem excluir a conta "Aplicativo WhatsApp Business" (incidente do Achado 6.2).
- Só a API oficial da Meta; nada de bibliotecas não oficiais (ADR-001).
- O usuário prefere passo a passo curto, um de cada vez, em português.
- Operações de navegador e terminal acontecem no servidor Debian do homelab (usuário `dll`). Sessões na nuvem não alcançam essa máquina.
