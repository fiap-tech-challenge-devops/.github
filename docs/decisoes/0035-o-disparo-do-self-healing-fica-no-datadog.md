# 0035 — O disparo do self-healing fica no Datadog, não passa pelo PagerDuty

**Status:** aceita · **Domínio:** Observabilidade · CI/CD · **Data:** 30/10/2026 · **Fase:** 4

## Contexto

Com o PagerDuty já no lugar como gestor de incidentes, a pergunta aparece sozinha: **por que o Datadog chama o GitHub direto, em vez de o PagerDuty disparar o self-healing?**

A intuição é boa. Hoje o Datadog manda para três destinos em paralelo — Slack, PagerDuty e o webhook do `repository_dispatch` — e o PagerDuty é só mais um deles, apesar de ser o único que existe para gerir incidentes. Faz pensar que a automação deveria pendurar nele.

Dois argumentos concretos sustentam a ideia, e os dois são reais:

**O enunciado exige duas fontes de alerta** — a stack opensource com Grafana e um APM comercial. Se a remediação tem que reagir às duas, hoje isso significa configurar webhook em dois lugares, com dois formatos de payload. Um funil resolveria.

**O PagerDuty deduplica alertas em incidentes nativamente**, que é uma versão pronta do disjuntor que a [0032](0032-triagem-por-sondas-e-report-no-slack.md) construiu à mão, contando runs anteriores pela API do Actions com `jq`.

## O impedimento técnico

O `repository_dispatch` do GitHub exige um corpo com forma específica:

```json
{ "event_type": "datadog-alert", "client_payload": { ... } }
```

O webhook do Datadog permite **moldar o corpo inteiro**, com variáveis de template. É exatamente por isso que ele chama o GitHub direto, sem nada no meio.

O webhook V3 do PagerDuty permite **cabeçalhos customizados, mas o corpo é o schema dele** — aninhado em `{"event": {"event_type": ..., "data": {...}}}`. O `event_type` não fica no nível de cima, e o GitHub recusaria com 422.

Fazer funcionar exigiria uma de duas coisas:

| Caminho | Por que não |
|---|---|
| Automation Actions ou Incident Workflows do PagerDuty | tier pago; a conta é gratuita, e a [0033](0033-pagerduty-em-stage-proprio.md) escolheu o gratuito de propósito, por ele não expirar |
| um adaptador no meio — Lambda com API Gateway | é exatamente o que a [0030](0030-self-healing-em-github-action.md) descartou, e pelos motivos que continuam valendo |

> **Ressalva:** a documentação do PagerDuty descreve cabeçalhos customizados e não menciona template de corpo, e a orientação oficial é transformar do lado de quem recebe. Não encontrei afirmação explícita de que não exista. Confere-se no painel, em `Integrations → Generic Webhooks (v3)`, ao criar uma subscription.

## O argumento que decidiu

O impedimento acima é contingente — some com um upgrade de plano. O que segue não.

**Funilar pelo PagerDuty serializa dois caminhos que a [0032](0032-triagem-por-sondas-e-report-no-slack.md) fez paralelos de propósito.**

Hoje o monitor dispara e os três destinos saem juntos. Nenhum depende do outro: se o Slack estiver fora, o PagerDuty abre e a remediação roda; se o PagerDuty estiver fora, o Slack avisa e a remediação roda.

Com o PagerDuty no meio, a remediação passa a depender do caminho de paginação. Se ele cair ou a integração quebrar, três coisas acontecem ao mesmo tempo: ninguém é avisado, **nada é consertado**, e **ninguém sabe que a automação não rodou**. É um modo de falha pior que qualquer um dos dois caminhos falhando sozinho — e é pior justamente porque é silencioso.

Somando o resto: mais um salto de latência; e um payload mais pobre, já que hoje chegam `$TAGS[service]`, `$ALERT_TRANSITION` e `$ALERT_CYCLE_KEY`, específicos e estáveis, contra um schema genérico de incidente do qual o serviço teria que ser escavado.

Tudo isso em troca de um funil que **ainda não é necessário**, porque só existe uma fonte de alerta.

## A decisão

**O disparo fica no Datadog. O PagerDuty é destino de notificação, não orquestrador.**

E ele já faz a parte dele do laço sem fiação nenhuma da nossa parte: em 30/10 o incidente #5 foi aberto pelo monitor e **fechado sozinho pela integração** — ver a observação na [0033](0033-pagerduty-em-stage-proprio.md).

### Uma tentativa que foi aberta e descartada

Antes dessa observação, a ideia de fazer a Action fechar o incidente pela API foi construída e chegou a PR — [togglemaster-iac#48](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/pull/48), fechada sem merge.

Ela se apoiava numa premissa da 0033 que dizia que o fechamento automático *"ainda não foi observado aqui"*. A premissa caiu, e com ela a justificativa. Fica registrada para que a ideia não seja refeita por quem reler só a 0033 antiga.

A revisão daquela PR deixou um achado que vale guardar, caso algo parecido volte: ela anotava em **todos** os incidentes abertos do serviço, sem casar com o monitor que disparou. Como os oito monitores paginam no mesmo serviço e dois são do `evaluation-service`, a nota sobre credencial cairia também no incidente de latência. Qualquer coisa que escreva num incidente precisa casar pelo monitor — e o casamento confiável é pelo `incident_key`, não pelo título.

## Alternativas descartadas

**Grafana e Datadog apontando cada um para o seu próprio webhook.** É o que acontecerá por omissão quando o Grafana começar a alertar: dois webhooks, dois payloads, a mesma Action. Feio, mas preserva a independência dos caminhos. Fica como a saída provável até existir motivo melhor.

**Normalizar no meio do caminho**, com um serviço que recebe de qualquer fonte e traduz para o `repository_dispatch`. É a resposta correta para muitas fontes, e é cedo demais: hoje seria um componente novo para resolver um problema que ainda tem N igual a um.

## Consequências

- **O `repository_dispatch` continua sendo o contrato de entrada** da automação, e quem quiser disparar precisa conseguir montar aquele corpo. É um requisito a verificar antes de adotar qualquer fonte nova
- **O disjuntor artesanal por `$ALERT_CYCLE_KEY` permanece.** Não há defeito hoje, porque só o monitor de taxa de erro do `evaluation-service` carrega o handle do webhook. Se outro monitor ganhar remediação, dois monitores da mesma falha viram dois ciclos distintos, logo dois runs concorrentes mexendo no mesmo segredo — e aí a deduplicação deixa de ser luxo
- **Nada muda no código.** Esta decisão registra por que uma coisa *não* foi feita, que é o tipo de registro que mais se perde

## O que esta decisão não resolve

**O funil, quando houver duas fontes de verdade.** A pergunta volta no dia em que o Grafana alertar, e a resposta provável é cada fonte montando o seu payload contra a mesma Action. O PagerDuty continua não sendo o candidato, pelos motivos acima.

**Se o corpo do webhook V3 é mesmo imutável.** Dois minutos no painel resolvem, e ninguém gastou ainda.

## Onde aprofundar

[0030](0030-self-healing-em-github-action.md) para por que a automação é uma Action e não uma Lambda · [0032](0032-triagem-por-sondas-e-report-no-slack.md) para o paralelismo entre notificar e agir, que esta decisão existe para preservar · [0033](0033-pagerduty-em-stage-proprio.md) para o PagerDuty como código, e para a observação do fechamento automático
