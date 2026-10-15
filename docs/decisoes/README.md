# Registro de decisões

Decisões que vinculam mais de um repositório. Cada uma registra **o que foi decidido, o que foi descartado e por quê**.

## Por que isto existe separado dos domínios

Os documentos em `docs/desafios/` de cada repositório contam *como foi resolver um problema*. São narrativa, e envelhecem junto com o código.

Uma decisão é outra coisa: ela **vincula quem vier depois**. Quem precisa saber por que o projeto está em Go 1.25 não deveria ter que descobrir que isso está num documento sobre CVE no `auth-service`.

E um registro de decisão não é corrigido quando muda — ele é **superado por outro**, e o antigo fica como histórico. Por isso a série é única e contínua: lida em ordem, ela é a linha do tempo do raciocínio do projeto. O domínio é um campo no cabeçalho, não uma pasta.

## Formato

Cabeçalho com `Status`, `Domínio`, `Data` e `Fase`. Depois: contexto, decisão, alternativas descartadas, consequências e onde aprofundar.

**Status possíveis:** `aceita`, `superada por NNNN`, `revertida`.

---

## Por domínio

### Kubernetes e GitOps

| # | Decisão | Status |
|---|---|---|
| [0001](0001-chart-de-terceiros-como-wrapper.md) | Chart de terceiros entra como dependência de um chart nosso | aceita |
| [0002](0002-um-chart-por-componente.md) | Um chart e uma Application por componente de plataforma | aceita |
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform | aceita |
| [0020](0020-tag-da-imagem-e-o-sha.md) | A tag da imagem é o SHA, e o CD escreve no GitOps | aceita |

### IaC

| # | Decisão | Status |
|---|---|---|
| [0012](0012-tres-stages-de-terraform.md) | Três stages de Terraform com estados independentes | aceita |
| [0013](0013-ecr-no-bootstrap.md) | Repositórios ECR no `bootstrap`, não no `infra` | aceita |
| [0014](0014-referencias-fixadas-por-tag.md) | Referências fixadas por tag, nunca por `main` | aceita |
| [0015](0015-oidc-sem-chave-estatica.md) | Autenticação na AWS por OIDC, sem chave estática | aceita |
| [0016](0016-apply-replaneja.md) | O `apply` replaneja em vez de consumir um plano salvo | aceita |
| [0017](0017-trivy-e-checkov.md) | Trivy e Checkov como dois motores independentes | aceita |
| [0021](0021-api-key-do-datadog-por-tf-vars.md) | A API key do Datadog por `tf-vars`, e o `plan` aceitando o input | aceita |

### Observabilidade

| # | Decisão | Status |
|---|---|---|
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform | aceita |
| [0004](0004-collector-no-meio.md) | Collector entre as aplicações e os backends | aceita |
| [0005](0005-datadog-como-apm.md) | Datadog como APM | aceita |
| [0008](0008-padrao-de-resource-attributes.md) | Padrão de resource attributes | aceita |
| [0009](0009-caminho-dos-logs.md) | Log por OTLP no local, stdout mais `filelog` em produção | aceita |
| [0010](0010-amostragem-em-100.md) | Amostragem de traces em 100% | aceita |
| [0021](0021-api-key-do-datadog-por-tf-vars.md) | A API key do Datadog por `tf-vars` | aceita |
| [0022](0022-datadog-connector-desde-o-inicio.md) | O `datadog/connector` junto do exporter | aceita |
| [0023](0023-datadog-como-codigo.md) | O que é construído no Datadog vira Terraform, num stage próprio | aceita |
| [0024](0024-encaixe-do-stage-datadog-na-esteira.md) | Plan do stage `datadog` na matriz, apply em esteira própria | aceita |
| [0025](0025-baseline-em-spot.md) | Baseline em dois nós spot, com cinco tipos de instância | aceita |

### CI/CD

| # | Decisão | Status |
|---|---|---|
| [0006](0006-fixar-versao-das-ferramentas.md) | Fixar a versão das ferramentas de lint e SAST na esteira | aceita |
| [0013](0013-ecr-no-bootstrap.md) | Repositórios ECR no `bootstrap`, não no `infra` | aceita |
| [0014](0014-referencias-fixadas-por-tag.md) | Referências fixadas por tag, nunca por `main` | aceita |
| [0015](0015-oidc-sem-chave-estatica.md) | Autenticação na AWS por OIDC, sem chave estática | aceita |
| [0016](0016-apply-replaneja.md) | O `apply` replaneja em vez de consumir um plano salvo | aceita |
| [0017](0017-trivy-e-checkov.md) | Trivy e Checkov como dois motores independentes | aceita |
| [0018](0018-gate-em-critical.md) | Gate em CRITICAL; lint e SAST reportam sem bloquear | aceita |
| [0019](0019-imagem-so-no-push-para-main.md) | Imagem construída no PR, publicada só no push para `main` | aceita |
| [0020](0020-tag-da-imagem-e-o-sha.md) | A tag da imagem é o SHA, e o CD escreve no GitOps | aceita |
| [0021](0021-api-key-do-datadog-por-tf-vars.md) | A API key do Datadog por `tf-vars`, e o `plan` aceitando o input | aceita |

### Serviços

| # | Decisão | Status |
|---|---|---|
| [0007](0007-permanecer-em-go-1-25.md) | Permanecer em Go 1.25 e OTel 1.46 | aceita |
| [0011](0011-go-redis-v8-para-v9.md) | Migrar o `go-redis` da v8 para a v9 | aceita |

---

## Por fase

### Fase 4 — Observabilidade

Registradas enquanto a fase acontece. Em ordem cronológica, elas contam como ela se desenrolou:

| # | Decisão | Data |
|---|---|---|
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps | 08/10 |
| [0004](0004-collector-no-meio.md) | Collector entre as aplicações e os backends | 08/10 |
| [0005](0005-datadog-como-apm.md) | Datadog como APM | 08/10 |
| [0008](0008-padrao-de-resource-attributes.md) | Padrão de resource attributes | 08/10 |
| [0010](0010-amostragem-em-100.md) | Amostragem em 100% | 08/10 |
| [0001](0001-chart-de-terceiros-como-wrapper.md) | Chart de terceiros como wrapper | 10/10 |
| [0002](0002-um-chart-por-componente.md) | Um chart por componente | 10/10 |
| [0006](0006-fixar-versao-das-ferramentas.md) | Fixar a versão das ferramentas | 10/10 |
| [0007](0007-permanecer-em-go-1-25.md) | Permanecer em Go 1.25 | 10/10 |
| [0009](0009-caminho-dos-logs.md) | Caminho dos logs | 10/10 |
| [0011](0011-go-redis-v8-para-v9.md) | `go-redis` v8 para v9 | 10/10 |
| [0021](0021-api-key-do-datadog-por-tf-vars.md) | A API key do Datadog por `tf-vars` | 14/10 |
| [0022](0022-datadog-connector-desde-o-inicio.md) | O `datadog/connector` junto do exporter | 14/10 |
| [0023](0023-datadog-como-codigo.md) | O Datadog como código, num stage próprio | 15/10 |
| [0024](0024-encaixe-do-stage-datadog-na-esteira.md) | Encaixe do stage `datadog` na esteira | 15/10 |
| [0025](0025-baseline-em-spot.md) | Baseline em dois nós spot | 15/10 |

As duas últimas abrem a **rodada 3** — Datadog, alerta, PagerDuty, Slack e self-healing.

### Fase 3 — IaC, DevSecOps e GitOps

Registros **retroativos**, escritos durante a Fase 4 a partir do código e das narrativas em `docs/desafios/`. Por isso os números são altos: o número é a ordem em que a decisão foi *registrada*, não em que foi *tomada*.

Lidos em sequência, eles respondem "por que a esteira é assim":

| # | Decisão | Tema |
|---|---|---|
| [0012](0012-tres-stages-de-terraform.md) | Três stages com estados independentes | Como a infraestrutura é dividida |
| [0013](0013-ecr-no-bootstrap.md) | ECR no `bootstrap` | O que sobrevive ao `destroy` |
| [0014](0014-referencias-fixadas-por-tag.md) | Referências fixadas por tag | Reprodutibilidade |
| [0015](0015-oidc-sem-chave-estatica.md) | OIDC, sem chave estática | Como a esteira se autentica |
| [0016](0016-apply-replaneja.md) | O `apply` replaneja | Como a infraestrutura é aplicada |
| [0017](0017-trivy-e-checkov.md) | Trivy e Checkov, dois motores | Segurança da IaC |
| [0018](0018-gate-em-critical.md) | Gate em CRITICAL | O que reprova um PR |
| [0019](0019-imagem-so-no-push-para-main.md) | Imagem publicada só no push | Quando a imagem existe |
| [0020](0020-tag-da-imagem-e-o-sha.md) | Tag é o SHA; o CD escreve no GitOps | Como o código chega ao cluster |

### Fases 1 e 2

Sem registros. A Fase 1 foi a construção dos microsserviços e a Fase 2 o Kubernetes inicial; as decisões técnicas de lá foram substituídas pelas da Fase 3 — a infraestrutura manual deu lugar ao Terraform, e os manifests avulsos aos charts do GitOps. Escrever ADR de algo já superado registraria história, não compromisso.

O código daquele período vive no [`togglemaster-platform-legacy`](https://github.com/fiap-tech-challenge-devops/togglemaster-platform-legacy), hoje reaproveitado como ambiente local.

---

## Como acrescentar

1. Copie o arquivo anterior e incremente o número
2. Preencha `Domínio` e `Fase` no cabeçalho
3. Preencha contexto, decisão, **alternativas descartadas** e consequências
4. Acrescente nas duas tabelas acima
5. Se superar uma decisão existente, marque a antiga como `superada por NNNN` — **não apague**
