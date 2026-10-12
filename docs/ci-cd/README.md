# CI/CD — Esteiras

Cada serviço tem um arquivo de poucas linhas que chama um workflow compartilhado. A definição vive uma vez, no [`reusable-workflows`](https://github.com/fiap-tech-challenge-devops/reusable-workflows).

## Os estágios

| Estágio | Go | Python | Reprova? |
|---|---|---|---|
| Build e teste | `go build`, `go test` | `compileall`, `pytest` | **sim** |
| Lint | `golangci-lint` | `ruff` | não — `continue-on-error` |
| Segurança | `gitleaks`, `gosec`, `trivy fs` | `gitleaks`, `bandit`, `trivy fs` | **sim**, o gitleaks e o trivy |
| Imagem | build, `trivy image`, push no ECR | idem | **sim** |

**Vulnerabilidade CRITICAL reprova imediatamente.** Não há aprovação manual que contorne: sem esteira verde, nenhuma imagem chega ao ECR.

O SAST não reprova de propósito — a taxa de falso positivo trava a esteira por engano, e ferramenta que se aprende a ignorar não protege ninguém.

## A fronteira entre CI e CD

| | CI | CD |
|---|---|---|
| Roda em | pull request **e** push para `main` | apenas push para `main` |
| Faz | build, teste, lint, scans e imagem — publica só no push | atualiza a tag da imagem no repositório GitOps |
| Efeito no cluster | nenhum | o Argo CD detecta o commit e sincroniza |

Em pull request a imagem é construída e escaneada, mas **não publicada**: num evento `pull_request` o `github.sha` é o merge efêmero, que não existe no histórico.

## Onde está documentado

| Documento | Assunto |
|---|---|
| [`reusable-workflows/README.md`](https://github.com/fiap-tech-challenge-devops/reusable-workflows) | Workflow ou action, o gate de segurança, tag da imagem, versionamento |
| [`reusable-workflows/docs/`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/tree/main/docs) | Um documento por peça, com `example/caller.yml` copiável |
| `*/docs/desafios/03` | Achados de lint em cada serviço: `errcheck` em Go, `ruff` em Python |
| `*/docs/desafios/04` | CVEs encontrados e o que cada correção custou |

## Decisões que afetam este domínio

O que cada estágio reprova, e o que não reprova, está registrado com as alternativas descartadas.

| # | Decisão |
|---|---|
| [0018](../decisoes/0018-gate-em-critical.md) | O gate em CRITICAL, e por que lint e SAST só reportam |
| [0019](../decisoes/0019-imagem-so-no-push-para-main.md) | Imagem construída no PR, publicada só no push |
| [0020](../decisoes/0020-tag-da-imagem-e-o-sha.md) | Tag é o SHA, e o CD escreve no GitOps — em vez do Image Updater |
| [0006](../decisoes/0006-fixar-versao-das-ferramentas.md) | Fixar a versão das ferramentas de lint e SAST |
| [0014](../decisoes/0014-referencias-fixadas-por-tag.md) | Workflows compartilhados consumidos por tag |
| [0015](../decisoes/0015-oidc-sem-chave-estatica.md) | OIDC sem chave estática |
| [0016](../decisoes/0016-apply-replaneja.md) | Por que a esteira de IaC não passa o `tfplan` entre jobs |

## O que saber antes de mexer

**As versões das ferramentas estão fixadas** desde a `v2.2.5`. Rodar local com versão diferente dá resultado diferente do CI.

**Os checks carregam o prefixo do job chamador.** Um workflow chamado reporta como `<job do caller> / <job do chamado>` — renomear o job do caller quebra o merge de todos os PRs abertos, porque o ruleset exige os nomes exatos.

**A tag vem depois do commit, nunca antes.** Já aconteceu de uma tag apontar para um commit anterior aos workflows e o `apply` falhar sem criar job nenhum.
