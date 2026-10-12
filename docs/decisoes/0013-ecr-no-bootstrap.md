# 0013 — Repositórios ECR no `bootstrap`, não no `infra`

**Status:** aceita · **Domínio:** IaC · CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir da documentação existente.

## Contexto

Os cinco repositórios ECR são infraestrutura da aplicação, e o lugar intuitivo para eles seria o stage `infra`, junto do cluster que consome as imagens.

## Decisão

Eles vivem no **`bootstrap`**, o stage de ciclo de vida longo, junto do bucket de state e da role de CI.

## Alternativas descartadas

**ECR no `infra`.** Três motivos, em ordem de peso:

**A esteira de CI dos microsserviços passa a ser testável sem subir a infraestrutura.** Com o ECR no `infra`, nenhum serviço poderia publicar imagem antes de existir VPC, EKS e três bancos — o que acopla o desenvolvimento das aplicações ao ambiente completo.

**As imagens sobrevivem ao `destroy`.** O ambiente é derrubado entre sessões de trabalho por custo. Se o ECR fosse junto, cada reconstrução exigiria republicar as cinco imagens.

**O `destroy` do `infra` deixa de falhar.** Repositório com imagem publicada faz o Terraform parar em `RepositoryNotEmptyException`.

## Consequências

- O `bootstrap` deixa de ser só "o state" e passa a ser "o que sobrevive ao ambiente"
- A role de CI que publica no ECR fica no mesmo stage do recurso que ela acessa
- Um `destroy` seguido de `apply` recupera um ambiente funcional sem passar pela esteira dos cinco serviços

## Onde aprofundar

[`togglemaster-iac/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac), seção "Por que três stages"
