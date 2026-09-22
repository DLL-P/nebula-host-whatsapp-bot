# 7. Da implantação interna a um modelo de serviço replicável

## 7.1 Motivação

O conhecimento operacional condensado nas seções anteriores — em particular os achados sobre coexistência ([`05-descobertas-coexistencia-whatsapp.md`](05-descobertas-coexistencia-whatsapp.md)) e o catálogo de obstáculos ([`06-licoes-aprendidas.md`](06-licoes-aprendidas.md)) — tem valor que se estende além da implantação original: qualquer prestadora de serviços de TI que atenda pequenas e médias empresas enfrenta o mesmo problema ao implantar esse tipo de sistema para um cliente terceiro. Este documento descreve como essa experiência foi estruturada como um serviço replicável.

## 7.2 Segmentação por complexidade de risco

A variável que mais determina o esforço e o risco de uma implantação não é o volume de funcionalidades desejadas, mas uma única condição binária: **o número de telefone do cliente já está em uso ativo por clientes reais, ou é um número novo?**

- **Número novo / dedicado.** Registro direto pelo fluxo padrão da Cloud API, sem necessidade de coexistência, sem canal existente a preservar. Esforço tipicamente baixo (poucas horas), risco operacional mínimo.
- **Número em produção.** Exige o fluxo de coexistência desde o início, tempo de implantação reservado para lidar com os comportamentos não-determinísticos documentados na Seção 5, e disciplina operacional para nunca interromper o canal existente. Esforço maior, risco de disponibilidade não-trivial se conduzido sem o conhecimento prévio documentado neste repositório.

Essa segmentação é o primeiro ponto de decisão em qualquer implantação para terceiros, e determina o restante do planejamento.

## 7.3 Estrutura de entrega

Uma implantação completa, independentemente da complexidade, cobre as seguintes etapas (detalhadas operacionalmente em material interno, fora do escopo deste repositório público):

1. Verificação de identidade de conta e portfólio empresarial na plataforma Meta;
2. Criação e configuração do aplicativo de desenvolvedor;
3. Registro do número (fluxo direto ou coexistência, conforme segmentação da Seção 7.2);
4. Geração de credencial de acesso permanente (System User), nunca de credencial temporária;
5. Configuração e verificação de webhook, incluindo o passo de inscrição da WABA no aplicativo (Achado 1, Seção 5.2);
6. Validação end-to-end com teste real, considerando a limitação de primeira mensagem (Achado 2, Seção 5.3);
7. Configuração de perfil comercial, catálogo e conteúdo de FAQ com dados reais do negócio do cliente;
8. Checklist de entrega, incluindo orientação ao cliente sobre acesso multi-dispositivo (WhatsApp Web / Dispositivos Vinculados) como via de acesso independente da automação.

## 7.4 Dois componentes de valor comercial

A experiência de implantação sugere dois componentes de precificação distintos, com racionais econômicos diferentes:

**Implantação (esforço único).** O valor cobrado por uma implantação não corresponde ao tempo de interação com os painéis de configuração — corresponde ao custo evitado de descoberta dos obstáculos documentados nas Seções 5 e 6. Uma implantação conduzida por alguém sem esse conhecimento prévio tem risco não-trivial de gerar o mesmo tipo de incidente de indisponibilidade relatado na Seção 6.2. O diferencial de preço entre uma implantação de número novo e uma implantação de número em produção reflete diretamente essa diferença de risco.

**Manutenção e disponibilidade (recorrente).** Distinta da implantação, a manutenção recorrente tem seu valor ancorado na garantia de que degradações da camada de automação (Seção 5.4 — desconexões temporárias da API que não afetam o canal humano, mas afetam a automação) sejam identificadas e comunicadas antes que o cliente perceba um problema, e não depois. Esse componente de serviço se aproxima, em estrutura, de um serviço de monitoramento de disponibilidade — o produto entregue não é "o bot funcionando hoje", é "alguém identifica um problema antes de você".

## 7.5 Generalização para outros domínios de aplicação

Embora este material tenha sido produzido no contexto de uma prestadora de serviços de TI, a estrutura de risco descrita (canal de atendimento já em produção; automação de triagem sem substituir julgamento humano em casos complexos; necessidade de coexistência para não interromper atendimento durante a transição) generaliza para qualquer pequena ou média empresa cujo canal primário de atendimento ao cliente seja o WhatsApp — o que, no contexto de mercado descrito na Seção 1.3, é a maioria delas.
