# 1. Motivação e contexto do problema

## 1.1 Contexto de negócio

O sistema documentado neste repositório foi desenvolvido para uma prestadora de serviços de TI de pequeno porte cujo portfólio abrange quatro frentes distintas: suporte remoto (via ferramentas como AnyDesk), infraestrutura de redes, consultoria em cibersegurança e desenvolvimento de projetos sob medida. Esse tipo de negócio apresenta uma característica comum a prestadoras de serviço multi-especialidade: o primeiro contato do cliente — quase sempre via WhatsApp, no mercado brasileiro — carrega ambiguidade sobre qual frente de serviço se aplica, qual a urgência, e qual o nível de esforço de resposta necessário antes de um atendimento humano ser produtivo.

Sem triagem, cada mensagem recebida exige que um humano leia, classifique mentalmente e responda — mesmo quando a resposta é uma pergunta de esclarecimento genérica ("qual tipo de suporte você precisa?") ou uma informação de FAQ (horário de atendimento, formas de pagamento, área de cobertura). Esse padrão de trabalho não escala com o volume de mensagens e introduz latência de resposta, que é um fator competitivo direto: em canais de mensageria instantânea, tempo de primeira resposta é correlacionado com taxa de conversão.

## 1.2 Escopo escolhido: triagem, não substituição integral do atendimento

Uma decisão de escopo deliberada, tomada antes de qualquer implementação, foi **não** tentar construir um sistema que substitua o atendimento humano para os casos complexos (orçamentos, diagnósticos técnicos específicos). O sistema foi desenhado para:

1. Responder instantaneamente a perguntas de FAQ e triagem de categoria;
2. Coletar contexto inicial estruturado (tipo de serviço, urgência) antes do handoff;
3. Encaminhar para atendimento humano sempre que a confiança de classificação for baixa ou o assunto exigir julgamento técnico específico de caso.

Essa decisão de escopo tem uma justificativa de risco: um LLM respondendo diretamente a perguntas técnicas específicas (por exemplo, um diagnóstico de rede) sem supervisão humana introduz risco de erro consequente — o custo de uma resposta técnica incorreta em produção é assimétrico em relação ao custo de simplesmente encaminhar a conversa para um humano um pouco mais cedo. A arquitetura resultante (documentada em [`02-arquitetura.md`](02-arquitetura.md)) reflete essa escolha: o LLM classifica e informa, mas não decide sozinho quando o assunto é técnico e específico.

## 1.3 Por que WhatsApp e não outro canal

No mercado brasileiro de pequenas e médias empresas, o WhatsApp é, na prática, o canal de atendimento dominante — inclusive substituindo telefone e e-mail como primeiro ponto de contato. Qualquer automação de atendimento que não opere sobre esse canal tem adoção limitada, independentemente da qualidade técnica da solução. Essa é a razão pela qual a arquitetura não considerou alternativas como widgets de chat em site ou aplicativos dedicados como canal primário — eles existem, no roadmap, apenas como complementares.

## 1.4 Restrição não-negociável: continuidade do canal existente

Um fator de contexto que se mostrou central durante a implantação (documentado em detalhe em [`06-licoes-aprendidas.md`](06-licoes-aprendidas.md)) é que, para negócios que já operam há algum tempo, o número de WhatsApp em uso **já está em produção** com clientes reais antes de qualquer projeto de automação começar. Isso significa que a superfície de risco de qualquer migração técnica inclui não apenas "o projeto pode atrasar", mas "o canal de vendas e suporte do negócio pode ficar inoperante durante a transição". Esse fator de risco moldou diversas decisões de arquitetura documentadas neste repositório, em particular a escolha do modo de **coexistência** da Cloud API (ver [`03-decisoes-tecnicas.md`](03-decisoes-tecnicas.md), ADR-002) em vez de uma migração completa e disruptiva.
