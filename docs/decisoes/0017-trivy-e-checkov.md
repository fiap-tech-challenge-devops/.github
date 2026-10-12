# 0017 — Trivy e Checkov como dois motores independentes

**Status:** aceita · **Domínio:** IaC · CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir da documentação e do código da esteira.

## Contexto

A análise estática de IaC parece um problema resolvido por uma ferramenta só. Na primeira execução limpa do repositório, contra o mesmo código:

| Ferramenta | Achados |
|---|---|
| Trivy | 0 |
| Checkov | 34 |

Não é que uma estava errada. **Elas têm bases de regras diferentes**, e a de maior cobertura encontrou 34 coisas que a outra não procura.

O `tfsec`, que seria o terceiro candidato, foi **descontinuado e absorvido pelo Trivy** — usá-lo seria rodar o mesmo motor duas vezes.

## Decisão

As duas rodam, no mesmo job, **ambas bloqueantes** (`exit-code: 1` no Trivy, `soft_fail: false` no Checkov).

Duas regras de uso:

**O Trivy não avalia módulos que ele mesmo baixa.** Sem isso, ele resolve os `source` remotos, baixa a biblioteca `terraform-aws-modules` e analisa o código dela junto: **7 dos 8 achados da primeira execução vinham de lá**. Achado em módulo de terceiro não é acionável no consumidor — a correção seria alterar outro repositório, publicar tag e atualizar a referência. A biblioteca tem a própria esteira para isso.

A opção não é exposta como input da action, então ela mora num `trivy.yaml` passado por `trivy-config`.

**Nenhuma exceção entra sem justificativa escrita.** Cada `skip-check` do `.checkov.yaml` e cada linha do `.trivyignore` carrega o motivo em comentário. Um arquivo de exceções sem motivo registrado vira um jeito silencioso de desligar o gate — o oposto do que a esteira existe para fazer.

## Alternativas descartadas

**Só o Trivy.** Zero achados dá a sensação de aprovação, não a prova dela.

**Acrescentar o tfsec.** Mesmo motor do Trivy depois da absorção.

**`soft_fail: true` no Checkov para não travar o trabalho.** Converteria 34 achados em 34 linhas de log que ninguém leria. Dos 34, a maioria virou exceção justificada e **um virou correção real**: `AWS-0132`, bucket de state sem chave própria, foi resolvido com uma KMS key dedicada e `bucket_key_enabled` — não ignorado.

## Consequências

- Subir a versão de qualquer uma das duas pode reprovar código que passava; é o preço de um gate real, e por isso as versões são fixas — ver [0014](0014-referencias-fixadas-por-tag.md)
- O `.checkov.yaml` é longo, e isso é proposital: ele é o registro de por que cada regra não se aplica
- Duas exceções cobrem 25 dos 34 achados — `CKV_TF_1` (módulo por hash em vez de tag, cuja premissa é consumo de terceiro) e `CKV2_AWS_34` (SSM como `SecureString`, para dados que não são segredo)

## Onde aprofundar

[`togglemaster-iac/docs/desafios/03-devsecops-iac.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/docs/desafios/03-devsecops-iac.md) — a análise achado por achado
