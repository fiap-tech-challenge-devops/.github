# 0014 — Referências fixadas por tag, nunca por `main`

**Status:** aceita · **Domínio:** IaC · CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir da documentação existente.

## Contexto

Duas bibliotecas compartilhadas são consumidas por vários repositórios: o [`terraform-aws-modules`](https://github.com/fiap-tech-challenge-devops/terraform-aws-modules), com doze módulos, e o [`reusable-workflows`](https://github.com/fiap-tech-challenge-devops/reusable-workflows), com as esteiras.

Apontar para `main` seria mais simples e traria correções automaticamente.

## Decisão

Toda referência a biblioteca compartilhada é **fixada em tag**:

```hcl
source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks?ref=v0.1.0"
```

```yaml
uses: fiap-tech-challenge-devops/reusable-workflows/.github/workflows/python-ci.yml@v2.2.5
```

## Alternativas descartadas

**Referenciar `main`.** Um commit na biblioteca passaria a alterar o plano de todos os consumidores sem que ninguém tivesse mudado nada no repositório deles. O mesmo commit produziria planos diferentes em dias diferentes — e a esteira deixaria de ser reprodutível.

## Consequências

- **A adoção é individual:** cada consumidor sobe a referência quando decidir, e uma mudança pode ser validada em um serviço antes de alcançar os cinco
- Mudança na biblioteca exige PR, tag nova e bump nos consumidores — mais passos, de propósito
- **A tag vem depois do commit, nunca antes.** Já aconteceu de uma tag apontar para um commit anterior aos workflows e o `apply` falhar sem criar job nenhum
- O mesmo princípio foi estendido na Fase 4 para as ferramentas instaladas por gerenciador de pacote — ver [0006](0006-fixar-versao-das-ferramentas.md)

## Onde aprofundar

[`togglemaster-iac/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) e [`reusable-workflows/README.md`](https://github.com/fiap-tech-challenge-devops/reusable-workflows)
