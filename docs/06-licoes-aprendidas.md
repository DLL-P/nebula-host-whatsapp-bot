# 6. Lições aprendidas e catálogo de obstáculos operacionais

Este documento cataloga obstáculos operacionais reais encontrados durante a implantação, organizados por categoria, com a causa, o impacto e a mitigação adotada. O objetivo é permitir que implantações futuras — próprias ou de terceiros lendo este material — evitem o mesmo custo de descoberta.

## 6.1 Identidade de conta ambígua na plataforma Meta

**Situação.** A criação de aplicativo e a atribuição de ativos no Business Manager falharam repetidamente com mensagens de erro pouco descritivas (por exemplo, recusa de adicionar um recurso "porque o aplicativo não pertence à conta"), sem indicação clara da causa.

**Causa raiz.** O navegador estava autenticado com uma identidade de conta Meta diferente da esperada — especificamente, uma conta vinculada apenas a um perfil de Instagram, sem uma conta de Facebook associada, usada em vez da conta correta de Facebook do operador do negócio.

**Impacto.** Tempo significativo perdido investigando uma causa técnica que, na realidade, era um problema de identidade/sessão.

**Mitigação.** Antes de iniciar qualquer configuração de Business Manager, confirmar explicitamente qual identidade está autenticada (menu "Ver todos os perfis" no Facebook/Meta), e garantir que se trata de uma conta com Facebook real vinculado — não apenas Instagram.

## 6.2 Incidente de indisponibilidade real causado por migração incorreta

**Situação.** Durante a tentativa de liberar um número já em uso (para permitir seu registro na Cloud API), o aplicativo WhatsApp Business comum foi removido do dispositivo com a expectativa de que o registro na Cloud API assumiria imediatamente o canal. O registro, no entanto, permaneceu em estado "pendente" por um período — durante o qual o número não tinha **nenhum** canal de WhatsApp ativo, nem aplicativo nem API.

**Impacto.** Interrupção real do canal de atendimento para um número em produção, com clientes reais impossibilitados de iniciar ou continuar conversas, durante o intervalo entre a remoção do aplicativo e a resolução do problema.

**Causa raiz do erro de decisão.** A premissa de que "registrar na Cloud API" e "aplicativo comum removido" seriam uma transição instantânea e sem lacuna estava incorreta — o processo de registro tem uma janela de estado intermediário não instantânea, e não há garantia de que o canal antigo permaneça disponível como fallback durante essa janela quando removido preventivamente.

**Recuperação.** O canal foi restabelecido através de uma sequência não-documentada oficialmente: remoção do número do lado do Business Suite, reativação do aplicativo comum via dispositivo móvel, e reconexão via Business Suite no desktop — resultando em um novo registro de WABA/número, desta vez em modo de coexistência funcional.

**Mitigação adotada para implantações futuras.** Nunca remover o aplicativo comum de um número em uso ativo como parte do processo de configuração. Utilizar o fluxo oficial de coexistência (*Embedded Signup* com suporte a coexistência) desde o início, que foi desenhado especificamente para não exigir essa remoção. Ver ADR-002 em [`03-decisoes-tecnicas.md`](03-decisoes-tecnicas.md).

## 6.3 Remoção de WABA do portfólio não libera o número no nível do sistema

**Situação.** Ao tentar reutilizar um número já associado a uma WhatsApp Business Account diferente, a remoção dessa WABA do portfólio empresarial não foi suficiente — uma tentativa subsequente de registrar o mesmo número em outra WABA continuou retornando erro de "número já registrado".

**Causa raiz.** O vínculo entre um número de telefone e uma conta do WhatsApp existe em um nível de sistema separado do vínculo entre uma WABA e um portfólio empresarial. Remover a WABA do portfólio não desfaz o registro do número no sistema do WhatsApp propriamente dito.

**Mitigação.** Para liberar de fato um número já registrado, é necessário excluir a conta do WhatsApp associada a ele diretamente pelo aplicativo móvel (Configurações → Conta → Excluir minha conta) — não apenas removê-la da estrutura organizacional do Business Manager.

## 6.4 Diagnóstico incorreto de erro de restrição regional de mensageria

**Situação.** O envio de mensagens para números com um determinado código de país específico retornava um erro de restrição ("conta de negócio restrita de enviar mensagens para usuários neste país").

**Hipótese inicial (incorreta).** A causa foi inicialmente atribuída à ausência de um número de registro empresarial formal (equivalente a um CNPJ no contexto brasileiro) associado à conta.

**Causa real.** O bloqueio foi resolvido ao completar integralmente as informações de perfil de negócio (endereço, categoria, descrição) e concluir o registro do número real na Cloud API — sem qualquer exigência de documento de registro empresarial formal.

**Lição.** Erros de plataforma com mensagens genéricas tendem a gerar hipóteses de causa baseadas em intuição de conformidade regulatória, que nem sempre correspondem à causa técnica real. Vale verificar sistematicamente o estado de completude do perfil de negócio antes de investir tempo em hipóteses de conformidade documental.

## 6.5 Dependências de ferramentas auxiliares não verificadas previamente

**Situação.** Durante um teste agendado, a ferramenta de tunelamento local usada para expor um servidor de desenvolvimento à internet pública falhou ao iniciar por exigir uma conta autenticada previamente não configurada.

**Mitigação.** Validar e configurar todas as dependências de ferramentas auxiliares (contas, tokens de autenticação de serviços de terceiros usados apenas em ambiente de desenvolvimento) antes de qualquer janela de tempo compromissada com terceiros — o custo de descobrir essa dependência faltante durante uma demonstração ao vivo é maior do que descobri-la em preparação isolada.

## 6.6 Síntese de impacto

| Obstáculo | Categoria de impacto | Reversível sem custo? |
|---|---|---|
| Identidade de conta ambígua | Tempo (eficiência) | Sim |
| Migração incorreta de número em produção | Disponibilidade do canal de atendimento | Não — gerou indisponibilidade real |
| WABA removida do portfólio, número ainda preso | Tempo (eficiência) | Sim, com o passo correto |
| Diagnóstico incorreto de erro regional | Tempo (eficiência) | Sim |
| Dependência de ferramenta não verificada | Tempo (eficiência), risco de imagem perante cliente | Sim |

O único obstáculo com impacto direto sobre disponibilidade de produção (6.2) foi também o único decorrente de uma decisão de arquitetura evitável — o que reforça a ADR-002 (uso de coexistência desde o início) como a mitigação estrutural mais relevante deste conjunto de achados.
