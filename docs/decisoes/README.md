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

### Observabilidade

| # | Decisão | Status |
|---|---|---|
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform | aceita |
| [0004](0004-collector-no-meio.md) | Collector entre as aplicações e os backends | aceita |
| [0005](0005-datadog-como-apm.md) | Datadog como APM | aceita |
| [0008](0008-padrao-de-resource-attributes.md) | Padrão de resource attributes | aceita |
| [0009](0009-caminho-dos-logs.md) | Log por OTLP no local, stdout mais `filelog` em produção | aceita |
| [0010](0010-amostragem-em-100.md) | Amostragem de traces em 100% | aceita |

### CI/CD

| # | Decisão | Status |
|---|---|---|
| [0006](0006-fixar-versao-das-ferramentas.md) | Fixar a versão das ferramentas de lint e SAST na esteira | aceita |

### Serviços

| # | Decisão | Status |
|---|---|---|
| [0007](0007-permanecer-em-go-1-25.md) | Permanecer em Go 1.25 e OTel 1.46 | aceita |
| [0011](0011-go-redis-v8-para-v9.md) | Migrar o `go-redis` da v8 para a v9 | aceita |

---

## Por fase

### Fase 4 — Observabilidade

Todas as onze. Em ordem cronológica, elas contam como a fase se desenrolou:

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

### Fases 1 a 3

Não há registros. As decisões daquelas fases estão nas narrativas dos `docs/desafios/` de cada repositório — o registro começou na Fase 4. Se alguma delas for revisitada, vale escrever o ADR retroativo.

---

## Como acrescentar

1. Copie o arquivo anterior e incremente o número
2. Preencha `Domínio` e `Fase` no cabeçalho
3. Preencha contexto, decisão, **alternativas descartadas** e consequências
4. Acrescente nas duas tabelas acima
5. Se superar uma decisão existente, marque a antiga como `superada por NNNN` — **não apague**
