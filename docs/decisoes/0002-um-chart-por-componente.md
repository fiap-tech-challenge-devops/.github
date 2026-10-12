# 0002 — Um chart e uma Application por componente de plataforma

**Status:** aceita · **Domínio:** GitOps · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

A primeira versão da pasta `platform/` tinha um chart único chamado `observability`, com o Collector como dependência. Prometheus, Loki e Grafana entrariam como dependências do mesmo chart.

## Decisão

Um chart e uma Application **por componente**, agrupados por domínio na árvore de pastas:

```
platform/
└── observability/
    ├── otel-collector/
    ├── kube-prometheus-stack/
    └── loki/
```

A pasta de domínio é navegação humana — o Argo lê caminho explícito.

## Alternativas descartadas

**Chart único com várias dependências.** Traria quatro problemas de uma vez: a tela do Argo mostraria "Degraded" sem dizer qual peça caiu; o `values.yaml` acumularia blocos de subchart aninhados; subir a versão do Loki redesenharia o Prometheus junto; e um rollback levaria todos.

## Consequências

- Cada componente tem saúde, sync e rollback próprios no Argo
- Mais arquivos de Application, mas todos pequenos e no mesmo formato
- As Applications continuam **planas** em `applications/` — a Application raiz lê aquele diretório sem recursão
- A pasta de domínio abre espaço para `controllers/`, se External Secrets e KEDA saírem do Terraform
- Manifestos próprios vão no `templates/` do componente de que dependem, sem precisar de sync wave

## Onde aprofundar

`togglemaster-gitops/platform/README.md`
