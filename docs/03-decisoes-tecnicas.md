# 3. Decisões técnicas (ADR)

Este documento registra as decisões de arquitetura relevantes no formato *Architecture Decision Record* (ADR): contexto, alternativas consideradas, decisão tomada e consequências. O objetivo é permitir que decisões sejam revisitadas no futuro com o raciocínio original preservado, e não apenas o resultado.

---

## ADR-001 — Canal de mensageria: WhatsApp Cloud API oficial

**Contexto.** Existem duas famílias de abordagem para integrar um sistema a um número de WhatsApp: (a) a API oficial da Meta (Cloud API ou On-Premises API), que exige processo de configuração formal via Business Manager; (b) bibliotecas não-oficiais que emulam um cliente WhatsApp Web (ex.: Baileys, whatsapp-web.js), que não exigem aprovação da Meta e têm configuração inicial mais simples.

**Alternativas consideradas.**
- Bibliotecas não-oficiais: menor barreira de entrada, mas operam em violação aos Termos de Serviço do WhatsApp. O risco associado é o banimento do número — que, para um número comercial já em uso por clientes reais, representa perda total do canal de atendimento sem aviso prévio nem recurso formal.
- Cloud API oficial: maior custo de configuração inicial (processo de verificação, requisitos de Business Manager), mas sem risco contratual de banimento por uso da API em si.

**Decisão.** Cloud API oficial da Meta, para qualquer número em produção.

**Consequências.** O custo de configuração inicial é significativamente mais alto e envolve processos administrativos da Meta com pouca previsibilidade (tempos de revisão variáveis, mensagens de erro pouco descritivas). Esse custo é tratado como investimento único, amortizado pela eliminação do risco de banimento. A maior parte dos achados documentados em [`05-descobertas-coexistencia-whatsapp.md`](05-descobertas-coexistencia-whatsapp.md) e [`06-licoes-aprendidas.md`](06-licoes-aprendidas.md) é consequência direta desse custo de configuração.

---

## ADR-002 — Modo de conexão do número: coexistência, não migração completa

**Contexto.** A Cloud API suporta dois modos de operação para um número: migração completa (o aplicativo WhatsApp Business comum é desligado, e todo o tráfego passa exclusivamente pela API) e **coexistência** (o aplicativo comum permanece ativo em paralelo à API, ambos recebendo e podendo responder mensagens).

**Alternativas consideradas.**
- Migração completa: mais simples de configurar tecnicamente, e é o caminho padrão sugerido pela documentação da Meta para números novos.
- Coexistência: exige um fluxo de configuração específico (Embedded Signup com suporte a coexistência) e tem comportamento menos previsível (ver ADR-005 em `05-descobertas-coexistencia-whatsapp.md`), mas preserva o funcionamento do aplicativo comum durante e após a transição.

**Decisão.** Coexistência, para qualquer número já em uso ativo por clientes.

**Consequências.** Essa decisão foi tomada **depois** de um incidente em que a migração completa foi tentada num número em produção, causando indisponibilidade total do canal de atendimento por um período (documentado em `06-licoes-aprendidas.md`). O trade-off aceito é: maior complexidade de configuração e maior número de comportamentos não-documentados pela Meta (ver `05-descobertas-coexistencia-whatsapp.md`), em troca de eliminar o risco de indisponibilidade do canal durante a transição. Para números novos, sem uso prévio, a migração completa continua sendo a opção mais simples e recomendada — a coexistência só se justifica quando há continuidade de atendimento a preservar.

---

## ADR-003 — Camada de atendimento: Chatwoot como proprietário do canal, bot como Agent Bot

**Contexto.** Havia duas formas de estruturar a relação entre o servidor de orquestração (bot) e a plataforma de atendimento humano: (a) o bot fala diretamente com a Cloud API e, separadamente, registra/sincroniza conversas em alguma ferramenta de atendimento; (b) a ferramenta de atendimento (Chatwoot) é a dona da conexão com a Cloud API, e o bot opera como um consumidor de eventos dela (padrão "Agent Bot").

**Alternativas consideradas.**
- Bot como dono do canal: mais simples de implementar inicialmente (não depende de nenhuma ferramenta externa), mas exige construir do zero qualquer funcionalidade de inbox, fila, histórico e atribuição de conversas — funcionalidades que já existem, maduras, no Chatwoot.
- Chatwoot como dono do canal (Agent Bot): exige aprender e integrar com a API do Chatwoot, e depende da disponibilidade dessa plataforma. Em contrapartida, elimina a necessidade de reimplementar gestão de fila/histórico/atribuição.
- Orquestração via ferramenta de automação genérica (ex. n8n) entre bot e Chatwoot: avaliada e descartada — adicionar uma camada de orquestração visual genérica não trouxe benefício sobre manter a lógica de triagem em código versionado e testável diretamente no Agent Bot.

**Decisão.** Chatwoot como proprietário do canal; servidor de orquestração como Agent Bot consumidor de eventos.

**Consequências.** A lógica de triagem (categorização, FAQ) permanece a mesma independentemente de qual camada fala com a Meta — apenas o transporte de mensagens muda (Graph API direta vs. API do Chatwoot). Isso permitiu que as fases 2 e 3 da implementação (ver `04-fases-de-implementacao.md`) fossem construídas e testadas antes mesmo de o Chatwoot estar implantado, e depois portadas para o padrão Agent Bot sem reescrever a lógica de negócio.

---

## ADR-004 — Modelo de linguagem para classificação: modelo de porte pequeno

**Contexto.** A tarefa de classificação de intenção (qual categoria de serviço, e se a mensagem corresponde a uma pergunta de FAQ) é uma tarefa de classificação de texto curto, com um conjunto pequeno e fixo de categorias de saída.

**Alternativas consideradas.**
- Modelo de porte grande (maior capacidade, maior custo por chamada, maior latência).
- Modelo de porte pequeno/rápido: menor custo por chamada e menor latência, ao custo de capacidade de raciocínio mais limitada.

**Decisão.** Modelo de porte pequeno (Claude Haiku), com saída estruturada (schema fixo) em vez de texto livre.

**Consequências.** Para uma tarefa de classificação com poucas categorias e sem necessidade de raciocínio multi-etapa, a diferença de qualidade entre um modelo pequeno e um grande é marginal, enquanto a diferença de custo por chamada e de latência percebida pelo usuário final é significativa — e a latência de resposta é, conforme discutido em `01-motivacao.md`, um fator direto de qualidade do atendimento. A saída estruturada (em vez de texto livre interpretado por regras frágeis) elimina uma classe inteira de bugs de parsing e torna o comportamento do sistema mais previsível.

---

## ADR-005 — Hospedagem: VPS self-hosted, não SaaS

**Contexto.** A camada de atendimento (Chatwoot) pode ser consumida como SaaS gerenciado pelo próprio fornecedor, ou implantada de forma self-hosted em infraestrutura própria.

**Alternativas consideradas.**
- SaaS gerenciado: menor esforço operacional, custo recorrente por assento/uso, dados de clientes armazenados em infraestrutura de terceiros.
- Self-hosted em homelab (infraestrutura doméstica já existente): custo marginal baixo, mas dependente de disponibilidade de internet e energia residencial, com risco de indisponibilidade fora do controle do operador.
- Self-hosted em VPS: custo mensal baixo e previsível, disponibilidade e conectividade de nível de datacenter, controle total sobre os dados.

**Decisão.** VPS self-hosted via Docker Compose.

**Consequências.** A diferença de custo mensal entre manter a infraestrutura em homelab e em uma VPS de baixo custo se mostrou pequena o suficiente para não justificar o risco de disponibilidade associado a depender de infraestrutura residencial para um canal de atendimento comercial. O controle total sobre os dados também simplifica a postura de conformidade com a LGPD, por não depender da política de tratamento de dados de um fornecedor terceiro de SaaS de atendimento.
