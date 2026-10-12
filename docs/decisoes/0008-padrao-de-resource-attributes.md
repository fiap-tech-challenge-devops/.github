# 0008 — Padrão de resource attributes

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 08/10/2026 · **Fase:** 4

## Contexto

Todo dado de telemetria carrega atributos que dizem de onde veio. É o que faz o APM desenhar o Service Map e o que permite filtrar no Grafana. Sem padronização, cada serviço inventa o seu e a agregação não funciona.

A primeira versão do padrão usava apenas `service.name`, `service.version` e `deployment.environment` — e tinha três problemas, encontrados ao revisar a especificação.

## Decisão

| Atributo | Valor | Origem |
|---|---|---|
| `service.name` | nome do repositório | nome do release Helm |
| `service.namespace` | `togglemaster` | values do chart base |
| `service.version` | SHA do commit | tag da imagem |
| `service.instance.id` | nome do pod | Downward API |
| `deployment.environment.name` | `prod` | values do chart base |

Injetados pelo chart base, **uma vez**, para os cinco serviços. Os atributos `k8s.*` vêm do Collector.

## O que estava errado na primeira versão

**`deployment.environment` está depreciado** desde o semconv 1.27; o nome atual é `deployment.environment.name`. Não é cosmético: é o atributo que o Datadog lê para montar a tag `env`.

**Faltava `service.namespace`**, que é o que agrupa os cinco serviços como um sistema só no Service Map.

**Faltava `service.instance.id`.** Sem ele, réplicas do mesmo serviço são indistinguíveis — e o `analytics-service` escala de 0 a 15 pods.

## Consequências

- Trace, log e métrica de qualquer serviço são filtráveis pelos mesmos campos
- O `service.version` liga qualquer trace ao commit exato, sem tabela intermediária
- Trocar endpoint, ambiente ou amostragem é um commit no chart base, não cinco
- **Inconsistência conhecida e aceita:** em Python o SDK gera um UUID próprio para `service.instance.id`, que prevalece sobre o valor do ambiente. Os dois são válidos — a convenção recomenda UUID, e o nome do pod vem da convenção de Kubernetes. Impacto baixo, porque `k8s.pod.name` cobre a identidade nos cinco

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), Parte 1
