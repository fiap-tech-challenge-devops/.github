# 0022 — O `datadog/connector` entra junto do exporter, não depois

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 14/10/2026 · **Fase:** 4

## Contexto

Ligar o Datadog parece ser uma linha: acrescentar um exporter à pipeline, como a [0004](0004-collector-no-meio.md) prometeu. E é — para **ver** traces.

Só que o Datadog não deriva sozinho as métricas de APM por serviço — requisições por segundo, taxa de erro, latência por percentil. Quem as calcula a partir dos spans é um componente separado, o `datadog/connector`, que recebe traces e **emite métricas**: ele aparece como exporter na pipeline de traces e como receiver na de métricas.

Isso importa agora porque a parte seguinte da rodada é o monitor de 5xx do `auth-service`, e é exatamente uma dessas métricas que ele vai consultar.

## Decisão

O connector entra **no mesmo PR** que o exporter. Os traces vão para os dois destinos:

```yaml
traces:
  exporters: [debug, datadog/connector, datadog]
metrics:
  receivers: [otlp, datadog/connector]
  exporters: [debug, datadog]
```

E, no mesmo movimento, **a verbosidade do `debug` cai de `detailed` para `basic`**.

## Alternativas descartadas

**Só o exporter agora, o connector quando o monitor precisar.** Entregaria o requisito de APM do enunciado — Service Map e trace distribuído — com menos peças. Descartada porque o connector **não é um acréscimo isolado**: ele muda a topologia das pipelines de traces *e* de métricas. Fazer isso depois é mexer na peça central do roteamento no meio da fase, quando já houver alerta dependendo dela.

**Métricas HTTP do OTel em vez das de APM.** O `http.server.request.duration` com `http.response.status_code` daria a taxa de 5xx sem connector nenhum, e é padrão aberto em vez de específico de fornecedor. Fica registrada como alternativa real para o monitor — mas não substitui o connector, porque sem ele os painéis de serviço do Datadog ficam vazios, e eles são print obrigatório do relatório.

**Manter `debug` em `detailed`.** Era o certo enquanto ele era o único destino: foi com ele que validamos cache MISS com 19 spans contra HIT com 2, e o span link do `analytics-service`. Com o Datadog recebendo, cada span viraria dezenas de linhas no log do Collector — e, quando o Loki entrar na rodada 2, esse log passa a ser coletado e pago em retenção, para guardar em formato pior um dado que já está no Datadog.

Manter em `basic` preserva a função de diagnóstico que de fato importa: a contagem, que distingue "não chega nada" de "chega e o destino recusa".

## Consequências

- **Os recursos do Collector subiram** de 100m/256Mi com limite de 512Mi para 150m/384Mi com limite de 768Mi. O connector calcula estatísticas e o exporter mantém fila — trabalho que não existia quando o destino era o log. O chart deriva o `GOMEMLIMIT` do limite, então ele acompanha
- O `debug` continua nas três pipelines, e isso é intencional: ele é o que separa "a aplicação não emite" de "o backend não recebe" ([0004](0004-collector-no-meio.md))
- **O `datadog` é o primeiro exporter de *push* do projeto.** Com o `debug`, nada podia falhar; agora o dado em trânsito é responsabilidade do Collector, e por isso `sending_queue` e `retry_on_failure` entram junto. Num nó apertado, fila crescendo é pressão de memória, e o `memory_limiter` começa a recusar dado novo
- O connector existe **só na imagem `contrib`**, o que justifica retroativamente a troca de imagem feita na rodada 1

## Risco conhecido

O padrão de resource attributes ([0008](0008-padrao-de-resource-attributes.md)) usa `deployment.environment.name`, o atributo atual do semconv. O mapeamento do exporter do Datadog leu `deployment.environment`, hoje depreciado, por muito tempo. Se a tag `env` vier vazia, a correção é no Collector — um `resource` processor ou `DD_ENV` — e **não** no padrão dos serviços, que está correto.

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), seção do Datadog
