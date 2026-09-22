# 4. Metodologia de implementação: fases incrementais

A implementação seguiu uma progressão deliberadamente incremental, com cada fase produzindo um artefato funcional e testável antes de avançar para a próxima. Essa abordagem foi escolhida em vez de um desenho completo seguido de implementação monolítica, por duas razões: (1) a superfície de erro em integrações com APIs de terceiros (Meta, Chatwoot) é alta e melhor descoberta incrementalmente; (2) cada fase entrega valor demonstrável de forma independente, permitindo validação com o operador do negócio antes de comprometer esforço na fase seguinte.

## Fase 1 — Conectividade básica

**Objetivo.** Provar que o pipe de mensageria funciona de ponta a ponta: receber uma mensagem via webhook e responder com um eco simples.

**Critério de conclusão.** Uma mensagem enviada por um número de teste é recebida pelo servidor e uma resposta automática chega de volta ao remetente, sem nenhuma lógica de negócio envolvida.

**Racional.** Isolar problemas de infraestrutura (webhook, autenticação, formato de payload) de problemas de lógica de negócio. Depurar os dois simultaneamente aumenta significativamente o tempo até a primeira execução bem-sucedida.

## Fase 2 — Triagem por menu (sem IA)

**Objetivo.** Implementar a lógica de categorização mais simples possível: um menu de opções fixas (lista interativa do WhatsApp), cada uma mapeada a uma resposta pré-definida.

**Critério de conclusão.** O fluxo de triagem por menu é validado com payloads simulados, sem dependência de nenhuma API de LLM.

**Racional.** Essa fase estabelece a estrutura de dados de categorias (identificador, título, descrição, resposta) que é reutilizada, sem alteração de forma, pela fase seguinte — apenas o mecanismo de seleção de categoria muda (usuário escolhe manualmente vs. modelo classifica).

## Fase 3 — Triagem por classificação de intenção (IA)

**Objetivo.** Adicionar uma camada de classificação automática por LLM (ver ADR-004) que interpreta texto livre do usuário e o mapeia para uma das categorias já definidas na Fase 2, ou identifica que a mensagem corresponde a uma pergunta de FAQ.

**Critério de conclusão.** O classificador é validado com um conjunto de mensagens de teste cobrindo cada categoria e casos ambíguos, com fallback documentado para quando a confiança de classificação é baixa.

**Racional.** Mensagens de texto livre são a forma natural com que a maioria dos usuários interage com um número de WhatsApp — poucos usuários leem e navegam por um menu de opções antes de escrever o que precisam. A classificação por IA reduz o atrito da Fase 2 sem abandonar sua estrutura de categorias.

## Fase 4 — Integração com camada de atendimento (Chatwoot)

**Objetivo.** Migrar a lógica de orquestração para operar como Agent Bot de uma instância Chatwoot self-hosted (ver ADR-003), adicionando fila, histórico e handoff estruturado para atendimento humano.

**Critério de conclusão.** A inbox do Chatwoot recebe mensagens reais da Cloud API, o Agent Bot responde ou encaminha conforme a lógica das fases 2–3, e conversas marcadas para atendimento humano aparecem corretamente na fila.

**Estado no momento desta publicação.** Planejamento e implementação do código concluídos; implantação em infraestrutura de produção (VPS) pendente de decisão comercial (contratação de hospedagem), não de bloqueio técnico.

## Fase 5 — Integrações adicionais (roadmap)

Fases futuras cogitadas, ainda não iniciadas: integração com agenda/calendário para agendamento automático de visitas técnicas, e integração com planilha ou CRM leve para acompanhamento de funil comercial. Essas fases não têm dependência técnica das fases 1–4 além da disponibilidade da infraestrutura de produção.
