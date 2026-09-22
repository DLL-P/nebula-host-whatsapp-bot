# 5. Achados empíricos: comportamento do modo de coexistência da WhatsApp Cloud API

## 5.1 Propósito e metodologia

Este documento registra comportamentos observados empiricamente durante testes reais de disponibilidade em um número de produção operando em modo de **coexistência** (aplicativo WhatsApp Business comum + Cloud API simultaneamente — ver ADR-002 em [`03-decisoes-tecnicas.md`](03-decisoes-tecnicas.md)). Nenhum dos achados abaixo está documentado de forma explícita e acessível na documentação pública da Meta para desenvolvedores; todos foram obtidos por observação direta de comportamento em produção, com verificação cruzada via chamadas à Graph API.

Todos os identificadores de conta (WABA ID, Phone Number ID, tokens) foram substituídos por placeholders. Os comandos abaixo são reproduzíveis substituindo os placeholders pelos identificadores reais de qualquer conta de teste.

## 5.2 Achado 1 — Inscrição explícita da WABA no App é necessária e não é evidenciada na interface guiada

**Observação.** Mesmo com a URL de callback do webhook verificada com sucesso e o campo de evento `messages` assinado — ambos confirmados como "concluídos" na interface guiada do painel de desenvolvedores — nenhum evento de mensagem chegava ao endpoint configurado.

**Causa raiz identificada.** A WhatsApp Business Account (WABA) não estava inscrita (*subscribed*) no aplicativo, apesar de toda a configuração de webhook aparentar completa na interface:

```
GET /{waba-id}/subscribed_apps?access_token={token}
→ {"data": []}
```

**Correção.**

```
POST /{waba-id}/subscribed_apps?access_token={token}
→ {"success": true}
```

**Discussão.** Esse passo é uma etapa obrigatória do protocolo (a Graph API rejeita silenciosamente eventos para apps não inscritos — não há erro explícito, apenas ausência de entrega), mas não aparece como um item de checklist na interface de configuração guiada ("Casos de uso → Personalizar → Configuração da produção") no momento em que este documento foi escrito. Qualquer implantação deveria verificar esse endpoint explicitamente como parte do processo de validação, independentemente do que a interface guiada reporta como "concluído".

## 5.3 Achado 2 — A primeira mensagem de um contato após habilitar coexistência não é entregue via webhook

**Observação.** Após toda a configuração validada (webhook, assinatura de campo, inscrição da WABA), a primeira mensagem enviada por um contato ainda não chegava ao endpoint de webhook — embora fosse visivelmente recebida no aplicativo WhatsApp Business comum do dispositivo.

**Causa.** Esse é um comportamento documentado por terceiros (não pela Meta diretamente) como uma limitação conhecida do modo de coexistência: a primeira mensagem de um contato após a habilitação da coexistência para aquele número não é repassada ao webhook da Cloud API — aparecendo, do lado da API, como se nunca tivesse sido enviada. A partir da segunda mensagem do mesmo contato, a entrega via webhook ocorre normalmente.

**Implicação prática.** Qualquer roteiro de teste ou demonstração para um cliente deve prever esse comportamento explicitamente — testar com uma única mensagem e concluir que a integração está quebrada é um falso negativo recorrente.

## 5.4 Achado 3 — O status de conexão da API é independente do funcionamento do aplicativo comum

**Observação.** Em determinado momento durante testes, o campo de status do número reportado pela Graph API mudou de `CONNECTED` para `DISCONNECTED`:

```
GET /{phone-number-id}?fields=status,account_mode
→ {"status": "DISCONNECTED", "account_mode": "LIVE"}
```

Nesse intervalo, o aplicativo WhatsApp Business comum, no mesmo número, continuou recebendo e enviando mensagens normalmente para contatos reais, sem qualquer degradação perceptível.

**Discussão.** Em modo de coexistência, a camada de conectividade da Cloud API e a camada de conectividade do aplicativo comum (SMB — *Small/Medium Business*) não compartilham o mesmo indicador de disponibilidade. Um técnico observando apenas o status da API pode concluir erroneamente que o canal de atendimento está indisponível, quando na realidade apenas a integração automatizada está temporariamente afetada.

## 5.5 Achado 4 — Não há mecanismo de reconexão manual para números em modo de coexistência (SMB)

Ao tentar reverter o estado `DISCONNECTED` observado no Achado 3, duas chamadas de API tipicamente usadas para (re)registro de número foram testadas e ambas retornaram erro:

```
POST /{phone-number-id}/register  {"messaging_product": "whatsapp", "pin": "<PIN>"}
→ {"error": {"message": "Register endpoint is not available for SMB businesses", ...}}

POST /{phone-number-id}/smb_app_data  {"messaging_product": "whatsapp", "sync_type": "smb_app_state_sync"}
→ {"error": {"message": "(#133010) Account not registered", ...}}
```

Da mesma forma, não foi encontrado, na interface do WhatsApp Manager, nenhum controle de "reconectar" para esse tipo de número — apenas a opção de adicionar um número novo.

**Conclusão observada.** Para números em modo de coexistência (classificados internamente pela Meta como contas SMB), a reconexão da camada Cloud API após uma desconexão temporária parece ser inteiramente automática, gerenciada pela sincronização periódica entre o aplicativo comum e os servidores da Meta — sem superfície de controle manual exposta ao desenvolvedor ou ao operador do negócio, seja via API ou painel. Na prática, o estado `CONNECTED` foi restabelecido de forma espontânea, sem qualquer ação corretiva, dentro de uma janela de poucos minutos a algumas dezenas de minutos.

**Recomendação decorrente.** Tentar forçar a reconexão via exclusão e recriação de contas (ver relato de incidente em [`06-licoes-aprendidas.md`](06-licoes-aprendidas.md)) é uma ação de alto risco que não é necessária para resolver uma desconexão temporária da camada API em modo de coexistência — a intervenção correta, nesse cenário específico, é aguardar.

## 5.6 Síntese

| Achado | Camada afetada | Ação corretiva disponível |
|---|---|---|
| WABA não inscrita no App | Configuração (permanente até corrigido) | Chamada manual a `subscribed_apps` |
| Primeira mensagem não entregue | Comportamento esperado, transitório por contato | Nenhuma — reenviar mensagem de teste |
| Status `DISCONNECTED` temporário | Camada de conectividade Cloud API | Nenhuma — aguardar reconexão automática |
| Impossibilidade de reconexão manual (SMB) | Camada de conectividade Cloud API | Nenhuma — por design da plataforma |

O padrão comum entre os achados 2–4 é que o modo de coexistência prioriza a continuidade do aplicativo comum (garantindo que o proprietário do número nunca perca acesso ao WhatsApp) em detrimento de previsibilidade e controlabilidade da camada de automação — um trade-off razoável do ponto de vista da Meta, mas que precisa ser conhecido explicitamente por quem implementa e opera sistemas de automação sobre esse modo.
