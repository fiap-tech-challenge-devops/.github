# 0005 — Datadog como APM

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 08/10/2026 · **Fase:** 4

## Contexto

O enunciado da Fase 4 pede **uma** ferramenta comercial de APM, entre Datadog e New Relic, usando as contas gratuitas para educação.

## Decisão

**Datadog**, recebendo do Collector pelo exporter nativo, com o `datadog/connector` no pipeline de traces.

A imagem do Collector já é a **`contrib`**, porque o exporter e o connector do Datadog só existem nela.

## Alternativas descartadas

**New Relic.** Aceita OTLP nativo, sem exporter proprietário, o que é mais aderente ao padrão. Descartado por preferência da equipe e pelo Service Map do Datadog ser mais direto de demonstrar.

**Instrumentar com as bibliotecas `dd-trace`.** Seria uma instrumentação paralela, duplicando trabalho e amarrando o código ao fornecedor. Os spans do OTel **já são** o dado de APM — o Datadog entra como destino, não como origem. O único recurso perdido é o profiling contínuo, que não trafega por OTLP e não é pedido na fase.

## Consequências

- Trocar de fornecedor depois é trocar o exporter, sem tocar em nenhum serviço
- O `datadog/connector` **não é opcional**: sem ele o Datadog não calcula as métricas de APM por serviço, que alimentam painéis e monitores
- A `DD_API_KEY` vem do Secrets Manager via External Secrets
- **Não configurar `DD_ENV`, `DD_SERVICE` nem `DD_VERSION`** junto com os resource attributes: configurar o mesmo conceito por dois caminhos produz valores duplicados
- Por ser externo ao cluster, o Datadog é o caminho recomendado para o alerta que precisa sobreviver a um incidente — ver [0003](0003-observabilidade-no-gitops.md)

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), Parte 2
