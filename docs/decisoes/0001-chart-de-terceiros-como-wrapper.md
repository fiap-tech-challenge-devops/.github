# 0001 — Chart de terceiros entra como dependência de um chart nosso

**Status:** aceita · **Domínio:** Kubernetes · GitOps · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

As cinco Applications dos microsserviços apontam para o chart em `charts/base` e leem os values por caminho relativo. Funciona porque **chart e values moram no mesmo `source`**.

Ao acrescentar o OTel Collector, o chart passou a vir do repositório Helm do OpenTelemetry. Se o `source` aponta para lá, o `valueFiles` relativo deixa de resolver: o repositório Helm não contém nossos arquivos, e uma Application tem um `source` só.

## Decisão

Criar um chart nosso que declara o de terceiros como dependência:

```yaml
dependencies:
  - name: opentelemetry-collector
    version: 0.175.1
    repository: https://open-telemetry.github.io/opentelemetry-helm-charts
```

A Application volta a apontar para o nosso repositório, idêntica em formato às cinco existentes.

## Alternativas descartadas

**Values inline na Application.** Simples, sem peça nova, mas a configuração inteira do componente vira um bloco dentro do YAML da Application, misturando "o que instalar" com "como configurar".

**Application multi-source com `ref`.** Permite values em arquivo, mas o recurso ainda é marcado como beta no Argo CD e a interface web tem suporte parcial — o que importa, já que a tela do Argo entra na demonstração.

## Consequências

- Os values ficam em arquivo versionado e revisável em PR
- O `Chart.lock` fixa a versão, mesma ideia dos módulos Terraform fixados por tag
- Manifestos próprios podem morar no `templates/` do mesmo chart, nascendo e morrendo com o componente
- Os `.tgz` dos subcharts ficam fora do git; o Argo os baixa no repo-server
- Subir a versão do componente passa a ser editar o `Chart.yaml`

## Onde aprofundar

`togglemaster-gitops/docs/desafios/08-otel-collector-e-charts-de-terceiros.md` e `togglemaster-gitops/platform/README.md`
