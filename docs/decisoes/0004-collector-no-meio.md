# 0004 — Collector entre as aplicações e os backends

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 08/10/2026 · **Fase:** 4

## Contexto

O enunciado da Fase 4 exige o OTel Collector como peça central. A alternativa técnica seria cada serviço exportar direto para o backend.

## Decisão

Os cinco serviços conhecem **um endereço** — `otel-collector.observability.svc.cluster.local:4317` — e nada mais. Todo roteamento acontece no Collector.

## Alternativas descartadas

**Aplicação exportando direto para o backend.** Cada serviço precisaria conhecer o endereço do Datadog, a chave de API e o formato dele. Trocar de fornecedor seria mexer em cinco repositórios, reconstruir cinco imagens e fazer cinco deploys.

## Consequências

- Acrescentar um destino é acrescentar um exporter: **nenhum serviço é tocado, nenhuma imagem reconstruída**
- Amostragem, filtro de dado sensível e enriquecimento com metadados de Kubernetes acontecem num lugar só
- Os atributos `k8s.*` vêm do processor `k8sattributes`, e a aplicação não precisa conhecê-los
- O Collector vira ponto único de falha para a telemetria — mitigado com `sending_queue` e retry
- Em troca, há uma peça a mais para operar e dimensionar

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), Parte 2
