# Chatbot de Atendimento via WhatsApp — Estudo de Caso e Documentação Técnica

**Autor:** Nebula Host — Soluções de TI
**Domínio de aplicação:** Atendimento ao cliente automatizado para prestadoras de serviços de TI de pequeno/médio porte
**Status:** Em produção (Fases 1–3 concluídas; Fase 4 planejada)

## Resumo

Este repositório documenta a concepção, arquitetura e implantação de um sistema de triagem automatizada de atendimento via WhatsApp, construído sobre a WhatsApp Cloud API oficial da Meta, com classificação de intenção por LLM (Claude) e handoff estruturado para atendimento humano. O objetivo do documento é duplo: (1) registrar as decisões de arquitetura e as justificativas técnicas e de negócio por trás de cada uma; (2) relatar, de forma reprodutível, os obstáculos operacionais reais encontrados durante a implantação — em particular no modo de **coexistência** entre o aplicativo comercial padrão do WhatsApp e a Cloud API — que não estão documentados de forma acessível pela própria Meta.

A motivação para publicar esta documentação é que grande parte do conhecimento operacional necessário para implantar esse tipo de sistema com segurança (sem interromper um canal de atendimento já em produção) só é obtida por tentativa e erro. Este material condensa essa experiência.

## Stack tecnológica

| Camada | Tecnologia | Papel |
|---|---|---|
| Canal de mensageria | WhatsApp Cloud API (Meta, oficial) | Transporte de mensagens, sem risco de banimento associado a bibliotecas não-oficiais |
| Orquestração | Node.js (Express) | Webhook / Agent Bot que processa eventos de mensagem |
| Classificação de intenção | Claude API (Anthropic), modelo Haiku | Triagem de FAQ e categorização de intenção com fallback para humano |
| Camada de atendimento | Chatwoot (self-hosted) | Inbox unificado, fila, histórico, automações, handoff bot→humano |
| Infraestrutura | Docker Compose sobre VPS | Hospedagem self-hosted, com foco em controle de dados (LGPD) |

## Estrutura da documentação

- [`docs/01-motivacao.md`](docs/01-motivacao.md) — o problema de negócio e por que automação de triagem (não de todo o atendimento) foi o escopo escolhido
- [`docs/02-arquitetura.md`](docs/02-arquitetura.md) — visão geral dos componentes e o fluxo de dados, com diagrama
- [`docs/03-decisoes-tecnicas.md`](docs/03-decisoes-tecnicas.md) — registro de decisões de arquitetura (formato ADR: contexto, alternativas consideradas, decisão, consequências)
- [`docs/04-fases-de-implementacao.md`](docs/04-fases-de-implementacao.md) — metodologia incremental adotada, fase a fase
- [`docs/05-descobertas-coexistencia-whatsapp.md`](docs/05-descobertas-coexistencia-whatsapp.md) — achados empíricos sobre o comportamento do modo de coexistência da Cloud API, não documentados oficialmente
- [`docs/06-licoes-aprendidas.md`](docs/06-licoes-aprendidas.md) — catálogo de obstáculos operacionais encontrados e como foram mitigados
- [`docs/07-modelo-de-servico.md`](docs/07-modelo-de-servico.md) — como essa experiência de implantação foi traduzida em um serviço replicável para terceiros

## Escopo e limitações deste repositório

Este repositório contém **apenas documentação** — arquitetura, decisões, metodologia e achados técnicos. O código-fonte da implementação (webhook, integração com Chatwoot, testes de disponibilidade) é proprietário e não está incluído. Identificadores reais de conta (números de telefone, IDs de WhatsApp Business Account, tokens de acesso, endereços) foram removidos ou substituídos por placeholders em todos os exemplos — nenhuma credencial ou dado de cliente real aparece neste material.

## Licença

O conteúdo textual deste repositório é disponibilizado para fins de referência técnica e estudo. Reprodução do conteúdo é permitida com atribuição.
