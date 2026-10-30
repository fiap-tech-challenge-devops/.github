# Observabilidade

Único domínio cuja documentação é **transversal**: ela atravessa os cinco microsserviços, o GitOps e o Terraform. Por isso o conteúdo mora aqui, e não colado num repositório.

## Por onde começar

| Documento | Para quem |
|---|---|
| [**Guia**](guia.md) | Como o dado flui, o formato real de cada sinal, e a receita para plugar Prometheus, Loki, Grafana ou Datadog |
| [**Instrumentação: Python e Go**](instrumentacao.md) | Por que cada linguagem exige um caminho diferente, e o que é preciso escrever em cada uma |
| [**Roteiro de incidente**](roteiro-de-incidente.md) | Como encenar uma falha, ver o alerta disparar e recuperar — validação da cadeia e ensaio da demonstração |

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
| Alertas | pronto — 8 monitores, dois golden signals por serviço; os de taxa de erro com aviso em 5% e crítico em 10% |
| ChatOps no Slack | pronto — a Action reporta por incoming webhook, e o monitor pelo handle `@slack-ToggleMaster-alertas-prod` |
| PagerDuty | **pronto** — stage próprio, incidente aberto pelo monitor em 27/10/2026 e fechado sozinho pela integração em 30/10 |
| Self-healing | **validado em execução** — cadeia completa em 50s, 23/10/2026. A janela de confirmação de 90s que entrou em 30/10 ainda **não** rodou ponta a ponta |

## Trocar de conta Datadog

A conta é um **trial**. A troca tem duas frentes: a telemetria que o cluster envia, e os objetos que o Terraform gerencia na conta.

> **Antes de trocar as keys, rode `IaC — Destroy` com o stage `datadog`.**
>
> O estado do stage `datadog` guarda ponteiros para objetos da conta velha. Depois da troca, o Terraform procura esses objetos na conta nova e a API do Datadog responde **500** no `datadog_webhook_custom_variable` em vez de 404 — o provider não distingue "sumiu" de "quebrou" e aborta. Monitor devolve 404 limpo e se recupera sozinho; o custom variable, não.
>
> O destroy **também faz refresh**, então depois de trocar as keys nem destruir funciona. Com o estado vazio antes da troca, a conta nova é construção do zero e o problema não existe.
>
> **Se as keys já foram trocadas**, o jeito é limpar o estado à mão. Ele contém só objetos `datadog_*` — esse stage não declara provider AWS — e todos moram numa conta inalcançável, então não há o que perder:
>
> ```bash
> B=s3://togglemaster-iac-tfstate-$(aws sts get-caller-identity --query Account --output text)
> aws s3 cp $B/togglemaster/datadog.tfstate $B/togglemaster/datadog.tfstate.conta-antiga
> aws s3 rm $B/togglemaster/datadog.tfstate
> ```
>
> Aconteceu em 29/10/2026. Destruir e reconstruir o ambiente **não** resolve: nada do estado do `datadog` é AWS.

Para a telemetria:

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

Em 29/10 aconteceu de novo, por outro caminho: o cluster foi reconstruído **83 segundos antes** de o apply gravar a key nova, então o Collector nasceu com a antiga e o `SecretSynced` ficou verde apontando para o valor velho. **Condição pronta não quer dizer valor atual** — o que decide é comparar:

```bash
sm=$(aws secretsmanager get-secret-value --secret-id togglemaster/datadog/account \
  --query SecretString --output text | sed -E 's/.*"DD_API_KEY"[^"]*"([^"]*)".*/\1/')
k8s=$(kubectl -n observability get secret datadog-account \
  -o jsonpath='{.data.DD_API_KEY}' | base64 -d)
[ "$sm" = "$k8s" ] && echo iguais || echo DIFERENTES
```

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
| [0029](../decisoes/0029-dois-golden-signals.md) | Por que só dois dos quatro golden signals, e o que falta para os outros |
| [0030](../decisoes/0030-self-healing-em-github-action.md) | Onde a automação de self-healing executa |
| [0031](../decisoes/0031-self-healing-mora-no-iac.md) | Em qual repositório ela mora |
| [0032](../decisoes/0032-triagem-por-sondas-e-report-no-slack.md) | A triagem por sondas, e o Datadog notificando em paralelo à remediação |
| [0033](../decisoes/0033-pagerduty-em-stage-proprio.md) | PagerDuty como código, e por que os oito monitores paginam |
| [0034](../decisoes/0034-escada-de-severidade-e-espera-antes-de-remediar.md) | Aviso em 5% e crítico em 10%, e a espera que confirma antes de remediar |
| [0035](../decisoes/0035-o-disparo-do-self-healing-fica-no-datadog.md) | Por que o PagerDuty não dispara o self-healing |
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
