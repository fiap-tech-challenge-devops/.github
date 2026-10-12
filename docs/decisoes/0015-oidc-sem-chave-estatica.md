# 0015 — Autenticação na AWS por OIDC, sem chave estática

**Status:** aceita · **Domínio:** IaC · CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir da documentação existente.

## Contexto

As esteiras precisam de credenciais da AWS para aplicar Terraform e publicar imagens no ECR. O caminho comum é guardar `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` como secrets do repositório.

## Decisão

**Nenhum segredo de longa duração da AWS existe nos repositórios.** Os jobs pedem um token OIDC ao GitHub e o trocam por credenciais temporárias via `AssumeRoleWithWebIdentity`.

O que fica guardado é o **ARN da role**, que não é credencial.

```yaml
permissions:
  id-token: write     # sem isto o job nem pede o token
  contents: read
```

A trust policy restringe por `sub`, por repositório.

## Alternativas descartadas

**Chaves de acesso em secrets.** Credencial de longa duração que não expira sozinha, precisa de rotação manual, e vaza inteira se o log de um job a imprimir por engano.

## Consequências

- Não há o que rotacionar nem o que vazar
- Dois recursos precisam existir **antes** de qualquer esteira rodar, e são criados à mão: o OIDC provider na conta — que é por conta, não por projeto — e a role que as esteiras assumem, porque seria circular criá-la pela esteira que precisa assumi-la
- **A armadilha da claim `sub`:** a organização usa a claim customizada do GitHub, que injeta IDs imutáveis (`repo:org@283760261/repo@1314140933:ref:...`). O padrão clássico `repo:<org>/<repo>:*` **não casa** — o sufixo `@<id>` aparece antes da barra, onde o curinga final não alcança. O sintoma é `Not authorized to perform sts:AssumeRoleWithWebIdentity` com a trust policy parecendo correta
- A role de publicação no ECR é **a mesma para os cinco serviços**, com a trust policy impedindo um de se passar por outro

## Onde aprofundar

[`togglemaster-iac/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) e o diagrama "Quem autoriza o quê" em [`docs/esteira/`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/tree/main/docs/esteira)
