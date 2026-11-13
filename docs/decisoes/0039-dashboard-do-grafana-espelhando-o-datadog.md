# 0039 — O dashboard do Grafana espelha o do Datadog, e as três coisas que não traduzem

**Status:** aceita · **Domínio:** Observabilidade · Kubernetes · **Validação:** parcial · **Data:** 13/11/2026 · **Fase:** 4

## Contexto

A [0038](0038-dashboard-de-performance-no-datadog.md) trouxe um dashboard de performance para o Datadog, construído à mão. Ele ficou melhor que o do Grafana: latência por percentil, quebra por endpoint, throughput por código HTTP, comparação entre serviços numa tabela.

O dashboard do Grafana tinha quatro painéis — CPU dos nós, memória dos nós, requisições por serviço e logs ao vivo. Atende o enunciado, e só.

**A decisão é reescrever o do Grafana no mesmo desenho do Datadog**, sobre Prometheus e Loki.

Há uma restrição que não se negocia: o dashboard do Grafana é o que o enunciado exige, com *"uso de recursos do cluster, taxa de requisições dos microsserviços e painel de logs em tempo real"*. Nenhum desses três pode sair. O Datadog não tem nenhum deles — então o resultado não é uma cópia, é um superconjunto.

## O que traduziu direto

Mais do que se esperava. Os rótulos que o Collector expõe no Prometheus cobrem quase tudo que o Datadog usava:

| No Datadog | No Prometheus |
|---|---|
| `http.status_code` | `http_response_status_code` |
| `resource_name` | `http_route` |
| `trace.http.server.request` (percentis) | `_bucket` + `histogram_quantile` |
| `trace.http.server.request.hits` | `_count` das métricas de duração |
| variável `$service` | `exported_job`, por `label_values` |

Erro por código, falha de autenticação em 401, tabela comparativa, quebra por rota e as dez rotas mais lentas: tudo reproduzível.

## As três coisas que não traduzem

### 1. Duas famílias de métrica, em unidades diferentes

Medido no Prometheus:

| Serviço | Métrica | Unidade |
|---|---|---|
| `auth-service`, `evaluation-service` (Go) | `http_server_request_duration_seconds` | segundos |
| `flag-service`, `targeting-service` (Python) | `http_server_duration_milliseconds` | milissegundos |

As duas linguagens estão em versões diferentes do semconv, e o nome da métrica mudou junto com a unidade. Isso **não é defeito a corrigir aqui** — alinhar exigiria subir a instrumentação de dois serviços, e a [0007](0007-permanecer-em-go-1-25.md) já mostrou o que custa mexer em versão de biblioteca no meio da fase.

A adaptação tem duas formas, conforme o que se mede:

**Contagem não tem unidade.** Throughput, erros e totais unem as duas famílias num seletor só, por regex no `__name__`:

```promql
sum by (exported_job) (rate({__name__=~"http_server_request_duration_seconds_count|http_server_duration_milliseconds_count", ...}[$__rate_interval]))
```

**Percentil tem.** Cada painel de latência leva **duas consultas**, e a de milissegundos é dividida por 1000. O `le` dos buckets está na unidade da métrica, então não há como unir antes do `histogram_quantile`.

Um detalhe salvou os painéis agregados: **as duas famílias cobrem serviços disjuntos**. Como nenhum serviço emite as duas, `A or B` une os resultados sem colisão de rótulo — e é assim que a tabela comparativa e o `topk` das rotas mais lentas funcionam com uma expressão só.

### 2. Não existe métrica de mensageria

O grupo *Messaging* do Datadog mostra produzido × consumido e latência do consumidor, a partir de `trace.Producer.hits` e `trace.Consumer.hits`. Essas métricas são calculadas pelo `datadog/connector` ([0022](0022-datadog-connector-desde-o-inicio.md)) **a partir dos spans**.

O Prometheus não tem equivalente: o SDK do OpenTelemetry não emite métrica de mensageria por padrão, e nenhuma foi encontrada na conta. O KEDA também não é raspado, então profundidade de fila está fora.

A adaptação troca a medida pelo **efeito observável**:

| Painel | Fonte | O que mostra |
|---|---|---|
| Réplicas do `analytics-service` | `kube_deployment_status_replicas_ready` e `..._spec_replicas` | o KEDA subindo do zero — prova de que houve mensagem |
| Linhas de log por segundo | **Loki** | atividade do consumidor, como proxy de processamento |

É inferior ao original e está dito como tal. A alternativa honesta seria não ter a seção; tê-la com o rótulo certo — *proxy de processamento* — informa mais do que o silêncio.

### 3. Numerador vazio não é zero

No Datadog, `default_zero(errors) / hits` resolve o caso de não haver erro nenhum.

Em PromQL, sem erros o numerador **não casa com série alguma**, e a divisão volta vazia — o painel mostra *No data* em vez de `0%`, que é a pior leitura possível num painel de taxa de erro: parece que a medição quebrou quando o sistema está são.

Medido: a consulta de taxa de erro voltou vazia com o ambiente saudável, e passou a devolver `0` com a correção.

| Caso | Correção |
|---|---|
| agregado, sem rótulo | `... or vector(0)` |
| por serviço | `... or 0 * sum by (exported_job) (...)`, que gera zero para cada série presente |

## A decisão

**Sete seções, 26 painéis**, no `uid` existente `togglemaster-overview` — mudar o `uid` criaria um segundo dashboard em vez de substituir o primeiro.

| Seção | Origem |
|---|---|
| Visão geral | Datadog — stats e tabela comparativa |
| Latência | Datadog — p95 e p99 |
| Throughput e erros | Datadog — quatro painéis |
| Endpoints | Datadog — tabela por rota e rotas mais lentas |
| Consumidor assíncrono | **adaptado** — réplicas e atividade de log |
| Recursos do cluster | **exigido pelo enunciado**, não existe no Datadog |
| Logs em tempo real | **exigido pelo enunciado**, não existe no Datadog |

As duas últimas são a razão de o dashboard do Grafana continuar sendo o que atende o enunciado, e por que a [0026](0026-sem-dashboard-no-datadog.md) estava certa na leitura dela mesmo depois da 0038.

Os limiares de 5% e 10% aparecem como linhas tracejadas no painel de taxa de erro, para a tela mostrar os mesmos patamares que a [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md) definiu nos monitores.

## Alternativas descartadas

**Alinhar a instrumentação para uma família de métrica só.** Resolveria a raiz, e é o certo a prazo. Descartada por escopo: mexer na versão do semconv de dois serviços no meio da fase, com as esteiras reprovando por CVE a cada bump, é o risco que a [0007](0007-permanecer-em-go-1-25.md) documentou.

**Recording rules normalizando as unidades.** Uma regra `job:http_request_duration_seconds:p95` esconderia a dualidade dos painéis. Descartada porque acrescenta uma camada que precisa ser mantida e entendida, para evitar escrever duas consultas em quatro painéis.

**Reproduzir o grupo de mensageria instrumentando métricas próprias** no `analytics-service` — um contador de mensagens processadas. É a solução correta e é trabalho de aplicação, não de dashboard. Fica anotado.

**Dois dashboards no Grafana**, um para o enunciado e outro espelhando o Datadog. Descartada porque o enunciado pede *"no mínimo 1"*, e dividir faria o avaliador procurar em dois lugares.

## Consequências

- **O dashboard tem variável de serviço** (`$service`, multi, com *All*). As consultas usam `exported_job=~"$service"`, e o `allValue` é `togglemaster/.*`
- **Não há variável de ambiente.** O Datadog tem `$env`; aqui existe um ambiente só, e uma variável de um valor é ruído
- **Todas as consultas foram validadas contra o Prometheus do cluster** antes de entrar no arquivo. As duas de taxa de erro voltaram vazias na primeira tentativa, e foi assim que o problema do numerador apareceu
- **O `analytics-service` não aparece nas seções de HTTP**, porque não emite métrica de servidor HTTP. Está dito na nota do topo do dashboard, para ninguém procurar

## O que esta decisão não resolve

**A dualidade de unidade continua visível.** Quem abrir o JSON vê duas consultas em cada painel de latência, e vai se perguntar por quê. O comentário está na descrição do painel, que é o único lugar onde um dashboard aceita comentário.

**O consumo real de mensagens segue não medido.** Réplicas e linhas de log são efeito, não medida. Um contador no `analytics-service` resolveria.

**A validação é parcial.** As consultas foram verificadas uma a uma contra o Prometheus, mas o dashboard inteiro ainda não foi aberto no Grafana — e layout, transformações de tabela e junções por campo só se confirmam na tela.

## Onde aprofundar

[0038](0038-dashboard-de-performance-no-datadog.md) para o dashboard que serviu de referência · [0026](0026-sem-dashboard-no-datadog.md) para por que o do Grafana é o que atende o enunciado · [0022](0022-datadog-connector-desde-o-inicio.md) para de onde vêm as métricas de mensageria que o Prometheus não tem
