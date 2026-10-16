# 0026 — Não haverá dashboard customizado no Datadog

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 16/10/2026 · **Fase:** 4

## Contexto

A [0023](0023-datadog-como-codigo.md) colocou sob Terraform "o que é construído no Datadog", e listou `datadog_dashboard_json` entre os recursos. Daí nasceu uma pergunta de autoria: dashboard é trabalho visual, e com ele sob Terraform uma edição na UI é desfeita no próximo apply.

Essa pergunta consumiu um desenho inteiro — esteira de captura, normalização de JSON, auto-merge de PR. Até alguém perguntar se dashboard no Datadog é necessário.

**Não é.** Lendo o que o enunciado da fase exige:

| Requisito | Onde |
|---|---|
| "no mínimo 1 dashboard customizado", com recursos do cluster, taxa de requisições e painel de logs | **Grafana** |
| Distributed tracing e **Service Map** com os cinco serviços | APM |
| Alerta | "no Grafana **ou** no APM" |

Os prints obrigatórios do relatório confirmam: *dashboard do Grafana*, *trace distribuído*, *notificação de incidente*, *execução do self-healing*. O print de dashboard é do Grafana; o do Datadog é um trace.

E o que se pretendia construir **já existe pronto**: a página de serviços do APM, alimentada pelo `datadog/connector` ([0022](0022-datadog-connector-desde-o-inicio.md)), mostra requisições por segundo, taxa de erro e latência por percentil, por serviço. O Service Map é automático. Os dois requisitos do Datadog se resolvem sem um widget.

## Decisão

**Nenhum dashboard customizado no Datadog.**

O stage `datadog/` fica com **monitor, webhook e integrações** — todos HCL, direção única, PR normal. O dashboard customizado do projeto é o do **Grafana**, onde o enunciado o pede e onde já estava planejado como JSON versionado em ConfigMap.

Para os requisitos do Datadog, usam-se as **páginas nativas de APM**.

## Alternativas descartadas

**Dashboard autorado na UI e capturado por esteira.** Desenhado por completo antes de ser descartado, e vale registrar porque o desenho estava correto — o problema era o dashboard existir, não o mecanismo:

> A UI seria o editor e o Git a autoridade. Uma esteira `dashboard-sync.yml`, de disparo manual, buscaria em `GET /api/v1/dashboard/{id}`, normalizaria com `jq -S` removendo campos voláteis, escreveria em `datadog/dashboards/*.json`, abriria PR e o mergearia sozinha — porque o ruleset da `main` exige PR mas não exige aprovação. O recurso Terraform leria o arquivo com `file()`, então o `.tf` nunca mudaria.

Isso custava: uma esteira a mais, a calibração de quais campos remover (descobrível só contra o JSON real), a dúvida de se `github-actions[bot]` conta como mudança não atribuída para o `require_extra_approval_for_unattributed_changes` do ruleset, e um diff de PR reconhecidamente ilegível. **Toda essa complexidade existia para servir uma peça que não é exigida e cuja função o APM já cumpre.**

Pelo caminho foram descartadas, antes dessa, outras seis: HCL puro pelo custo de autoria; export manual pelos quatro passos por mudança; cron com PR, porque **o cron do GitHub Actions atrasou 4 a 7 horas neste projeto** e capturaria rascunho; cron commitando direto, que faria a UI ser a autoridade; event-driven por Audit Trail, que é add-on pago, dispara por limiar e não distingue intenção; e tag no dashboard como sinal, cuja premissa de campo `tags` editável pela UI não se confirmou.

**Um dashboard pequeno, linkado do alerta.** O argumento é bom: quando o PagerDuty acorda alguém às 3h, cair numa tela com o contexto daquele alerta é melhor que cair na home do APM. É prática real de SRE. Descartada porque um link para a página do serviço no APM, já filtrada, entrega o mesmo contexto sem dashboard — e sem a esteira que o manteria.

**Ter o dashboard nos dois, Datadog e Grafana.** Duas telas mostrando aproximadamente a mesma coisa, mantidas em lugares diferentes, livres para divergir. É a duplicação que já motivou remover o guia de observabilidade duplicado entre repositórios.

## Consequências

- **O `datadog/` fica só com fluxo de direção única.** Nenhuma peça é autorada na UI, então não há sync, não há normalização e não há captura. Monitor, webhook e integrações nascem em HCL e são revisados em PR como qualquer código
- **Some a peça mais complicada do desenho** — e a única cujo custo eu não sabia dimensionar
- A decisão de **qual métrica o monitor consulta** deixa de depender de construir um dashboard. O **Metrics Explorer** mostra as métricas `trace.*` disponíveis com os nomes exatos, que era a única informação que o dashboard ia revelar
- A [0023](0023-datadog-como-codigo.md) lista `datadog_dashboard_json` entre os recursos do stage. Ele não será usado — o resto da decisão segue válido
- **A conta Datadog não tem métrica de infraestrutura.** Sem Datadog Agent, e com o receiver `prometheus` do Collector em `null`, não há `kubernetes.*` nem `kubernetes_state.*`. Um dashboard ali seria mais pobre que o do Grafana de todo modo, que vê o cluster pelo Prometheus

## Onde aprofundar

Hub de [observabilidade](../observabilidade/README.md)
