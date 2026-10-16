# Observabilidade

Único domínio cuja documentação é **transversal**: ela atravessa os cinco microsserviços, o GitOps e o Terraform. Por isso o conteúdo mora aqui, e não colado num repositório.

## Por onde começar

| Documento | Para quem |
|---|---|
| [**Guia**](guia.md) | Como o dado flui, o formato real de cada sinal, e a receita para plugar Prometheus, Loki, Grafana ou Datadog |
| [**Instrumentação: Python e Go**](instrumentacao.md) | Por que cada linguagem exige um caminho diferente, e o que é preciso escrever em cada uma |

## Estado atual

Os cinco serviços emitem traces, métricas e logs para um Collector no cluster, que os roteia para o **Datadog**. A stack opensource — Prometheus, Loki e Grafana — ainda não existe.

| Frente | Situação |
|---|---|
| Instrumentação dos 5 serviços | pronta |
| Collector no cluster | pronto, exporters `datadog` e `debug` |
| Propagação síncrona (HTTP) | pronta — atravessa Python e Go |
| Propagação assíncrona (SQS) | pronta — span link entre produtor e consumidor |
| Prometheus, Loki, Grafana | a fazer |
| Datadog | pronto — APM, Service Map e trace distribuído validados em 15/10/2026 |
| Alertas, PagerDuty/OpsGenie, ChatOps | a fazer |
| Self-healing | a fazer |

## Trocar de conta Datadog

A conta é um **trial**. Quando expirar, a troca é em um lugar só, porque o Collector lê site e key do ambiente:

1. Criar a conta nova e gerar a **API key** em `Organization Settings` → `API Keys` (não a *Application key*)
2. Atualizar o secret `TF_VARS_INFRA` no `togglemaster-iac`:
   ```
   datadog_api_key=<a key nova>
   datadog_site=<o site novo, se não for datadoghq.com>
   ```
3. Rodar `IaC — Apply`, que atualiza a versão do segredo no Secrets Manager
4. **Forçar a sincronização do External Secrets.** O apply muda o Secrets Manager, mas o Secret do Kubernetes só acompanha no próximo `refreshInterval` — até 1h depois:
   ```
   kubectl annotate externalsecret datadog-account -n observability \
     force-sync="$(date +%s)" --overwrite
   ```
5. Reiniciar o Collector, que lê a variável apenas no boot:
   ```
   kubectl delete pod -n observability -l app.kubernetes.io/name=opentelemetry-collector
   ```

Os passos 4 e 5 são os dois necessários, e o 4 é o que se esquece: sem ele o restart recarrega a key **antiga**. Foi o que aconteceu na primeira troca, em 15/10 — o `curl` de validação abaixo apontou 403 no cluster enquanto o Secrets Manager já tinha a key certa.

Para conferir uma key antes de colocá-la no secret, ou para saber qual delas o cluster está usando:

```
# a key que você pretende usar
curl -s -o /dev/null -w '%{http_code}\n' https://api.datadoghq.com/api/v1/validate \
  -H "DD-API-KEY: <a key>"

# a key que o cluster está usando agora
curl -s -o /dev/null -w '%{http_code}\n' https://api.datadoghq.com/api/v1/validate \
  -H "DD-API-KEY: $(kubectl -n observability get secret datadog-account \
      -o jsonpath='{.data.DD_API_KEY}' | base64 -d)"
```

`200` é válida. `403` significa key errada — e a confusão mais comum é pegar a **Application key** (40 caracteres, prefixo `ddap_`) em vez da **API key** (32 hexadecimais, sem prefixo). Foi exatamente o erro da primeira tentativa.

Nenhum PR, em nenhum repositório. O site vive no mesmo segredo que a key justamente para os dois trocarem juntos — ver [0021](../decisoes/0021-api-key-do-datadog-por-tf-vars.md).

**O que a troca não recupera sozinha:** monitor, integrações e dashboards são configuração do painel e morrem com a conta. Por isso eles vão para um stage de Terraform próprio — [0023](../decisoes/0023-datadog-como-codigo.md) —, e a conta nova é reconstruída por apply. Sobra um núcleo manual: autorizar o Datadog no Slack e criar o serviço no PagerDuty são OAuth e não se automatizam.

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
| [0021](../decisoes/0021-api-key-do-datadog-por-tf-vars.md) | Como a API key do Datadog chega ao Collector |
| [0022](../decisoes/0022-datadog-connector-desde-o-inicio.md) | O `datadog/connector` junto do exporter, e o `debug` caindo para `basic` |
| [0023](../decisoes/0023-datadog-como-codigo.md) | Monitor, integrações e dashboards como Terraform, num stage próprio |
| [0024](../decisoes/0024-encaixe-do-stage-datadog-na-esteira.md) | Como o stage `datadog` entra nas esteiras de plan e apply |
| [0026](../decisoes/0026-sem-dashboard-no-datadog.md) | Sem dashboard no Datadog — o customizado é o do Grafana |
| [0028](../decisoes/0028-slack-para-chatops.md) | Slack para o ChatOps, e o passo de OAuth que fica manual |
| [0027](../decisoes/0027-ciclo-de-vida-do-stage-datadog.md) | Sobe com o ambiente, e é o primeiro a ser destruído |

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
