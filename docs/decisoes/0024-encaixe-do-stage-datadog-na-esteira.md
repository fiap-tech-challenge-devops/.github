# 0024 — Plan do stage `datadog` na matriz existente, apply em esteira própria

**Status:** aceita, **estendida pela [0027](0027-ciclo-de-vida-do-stage-datadog.md)** · **Domínio:** IaC · CI/CD · **Data:** 15/10/2026 · **Fase:** 4

> **O que mudou:** esta decisão dizia que `iac-apply.yml` e `iac-destroy.yml` ficariam intocados. Isso deixava "matar e subir tudo" sem subir o Datadog. A 0027 acrescenta o job `datadog` ao `iac-apply.yml` — sem `datadog/**` nos paths dele, então o isolamento decidido aqui é preservado — e o inclui na cadeia de destroy.

## Contexto

A [0023](0023-datadog-como-codigo.md) colocou monitor, dashboard e integrações num stage `datadog/` próprio. Falta decidir como ele entra nas esteiras.

As duas esteiras de IaC disparam de formas diferentes, e essa assimetria é o que torna a decisão não óbvia:

| | Filtro de path? |
|---|---|
| `iac-plan.yml`, em pull request | **não** — planeja a matriz inteira em toda PR |
| `iac-apply.yml`, em push na `main` | **sim** — `infra/**`, `addons/**` |

E há um fato do GitHub que decide a questão: **`on.paths` filtra o workflow inteiro, não job por job.**

## Decisão

**Plan:** o stage entra no `stages` do `iac-plan.yml` existente, com **`required: false`**.

**Apply:** esteira nova, `datadog-apply.yml`, com `paths: [datadog/**]`.

**`iac-apply.yml` e `iac-destroy.yml` ficam intocados.**

## Alternativas descartadas

**Acrescentar `datadog/**` aos paths do `iac-apply.yml`.** O caminho de menos arquivos, e o que falha pior.

Como `on.paths` filtra o workflow todo, um push que só mexe num dashboard dispararia também os jobs `apply infra` e `apply addons`. E o ambiente passa a maior parte do tempo **destruído**, por causa do destroy agendado da 01h — então ajustar um widget e dar push reconstruiria VPC, EKS e três bancos, com 16 minutos e custo de AWS, como efeito colateral invisível.

Não é risco hipotético: com o agendamento ativo, é o que aconteceria na maioria dos pushes.

**Esteiras próprias para plan e apply, as duas com filtro de path.** Isolamento mais limpo, e descartada por uma armadilha conhecida do GitHub: **check exigido pelo ruleset somado a filtro de path trava o merge.** Uma PR que não toca `datadog/` fica esperando para sempre por um check que nunca roda — o ruleset não sabe distinguir "pulado" de "pendente".

As saídas existem — não exigir o check, ou montar um job que sempre reporta —, mas as duas custam algo: perder o gate, ou acrescentar maquinaria. E um plan em esteira separada também ficaria fora do resumo por IA, que está configurado com `summary-stage: infra` no caller atual.

## Consequências

- **Plan do Datadog roda em toda PR**, inclusive nas que não têm relação. Custa segundos, e dá um ganho que não é óbvio: **plan vazio prova que nada driftou no painel**
- **`required: false` no começo**, de propósito. O plan passa a depender da API de um fornecedor; uma intermitência dele não deve bloquear merge de infraestrutura. Também evita mexer no ruleset da `main` agora, onde nome de check errado trava todos os PRs abertos. Vira `true` depois, se o gate se mostrar desejável
- **Um arquivo de workflow novo**, e o `iac-apply.yml` — que acabou de fazer um rebuild completo com sucesso — não é tocado
- A biblioteca `reusable-workflows` **não muda**: `terraform-plan.yml` e `terraform-apply.yml` já recebem `stage`, `state-bucket-prefix` e `tf-vars`, e servem a este stage como estão
- State com chave própria, `togglemaster/datadog.tfstate`, no mesmo bucket — backend parcial, igual aos outros stages
- O job `security` do plan varre o repositório todo, então Trivy e Checkov passam a enxergar `datadog/`. Não se espera achado relevante, mas é o tipo de surpresa que aparece no primeiro PR e parece defeito

## Onde aprofundar

[`reusable-workflows/docs/terraform-plan/`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/tree/main/docs/terraform-plan) e o hub de [CI/CD](../ci-cd/README.md)
