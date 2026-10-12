# Observabilidade

Único domínio cuja documentação é **transversal**: ela atravessa os cinco microsserviços, o GitOps e o Terraform. Por isso o conteúdo mora aqui, e não colado num repositório.

## Por onde começar

| Documento | Para quem |
|---|---|
| [**Guia**](guia.md) | Como o dado flui, o formato real de cada sinal, e a receita para plugar Prometheus, Loki, Grafana ou Datadog |
| [**Instrumentação: Python e Go**](instrumentacao.md) | Por que cada linguagem exige um caminho diferente, e o que é preciso escrever em cada uma |

## Estado atual

Os cinco serviços emitem traces, métricas e logs para um Collector no cluster. O Collector hoje só imprime o que recebe — **não há backend ainda**.

| Frente | Situação |
|---|---|
| Instrumentação dos 5 serviços | pronta |
| Collector no cluster | pronto, exporter `debug` |
| Propagação síncrona (HTTP) | pronta — atravessa Python e Go |
| Propagação assíncrona (SQS) | pronta — span link entre produtor e consumidor |
| Prometheus, Loki, Grafana | a fazer |
| Datadog | a fazer |
| Alertas, PagerDuty/OpsGenie, ChatOps | a fazer |
| Self-healing | a fazer |

## Decisões que afetam este domínio

| # | Decisão |
|---|---|
| [0003](../decisoes/0003-observabilidade-no-gitops.md) | Stack no GitOps, não no Terraform |
| [0004](../decisoes/0004-collector-no-meio.md) | Collector entre as aplicações e os backends |
| [0005](../decisoes/0005-datadog-como-apm.md) | Datadog como APM |
| [0007](../decisoes/0007-permanecer-em-go-1-25.md) | Permanecer em Go 1.25 e OTel 1.46 |
| [0008](../decisoes/0008-padrao-de-resource-attributes.md) | Padrão de resource attributes |
| [0009](../decisoes/0009-caminho-dos-logs.md) | Caminho dos logs: OTLP local, stdout em produção |
| [0010](../decisoes/0010-amostragem-em-100.md) | Amostragem em 100% |
| [0011](../decisoes/0011-go-redis-v8-para-v9.md) | `go-redis` da v8 para a v9 |

## Documentação por serviço

Cada repositório conta **o que foi feito nele**, com a investigação completa:

| Repositório | Assunto |
|---|---|
| `flag-service/docs/desafios/05` | Auto-instrumentação em Python e seus pontos cegos |
| `targeting-service/docs/desafios/05` | Repetição do padrão, com o `cursor_factory` corrigido preventivamente |
| `analytics-service/docs/desafios/05` | Consumo de fila, span link e convenção de mensageria |
| `auth-service/docs/desafios/05` | SDK em Go à mão, e por que o propagador é crítico |
| `evaluation-service/docs/desafios/05` | `context` em cinco camadas, Redis v9 e injeção no SQS |
| `togglemaster-gitops/docs/desafios/08` | O Collector e charts de terceiros no GitOps |
