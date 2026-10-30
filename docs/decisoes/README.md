# Registro de decisões

Decisões que vinculam mais de um repositório. Cada uma registra **o que foi decidido, o que foi descartado e por quê**.

## Por que isto existe separado dos domínios

Os documentos em `docs/desafios/` de cada repositório contam *como foi resolver um problema*. São narrativa, e envelhecem junto com o código.

Uma decisão é outra coisa: ela **vincula quem vier depois**. Quem precisa saber por que o projeto está em Go 1.25 não deveria ter que descobrir que isso está num documento sobre CVE no `auth-service`.

E um registro de decisão não é corrigido quando muda — ele é **superado por outro**, e o antigo fica como histórico. Por isso a série é única e contínua: lida em ordem, ela é a linha do tempo do raciocínio do projeto. O domínio é um campo no cabeçalho, não uma pasta.

## Formato

Cabeçalho com `Status`, `Domínio`, `Data` e `Fase`, mais `Validação` quando couber. Depois: contexto, decisão, alternativas descartadas, consequências e onde aprofundar.

**Status possíveis:** `aceita`, `superada por NNNN`, `revertida`.

Decisão raramente envelhece inteira — costuma ser um ponto dela que cai. Para isso há duas formas parciais, e as duas exigem **um parágrafo no topo dizendo o que mudou**, para quem chega pelo link não ler o ponto morto como vigente:

- `aceita, exceto no ponto X, superado pela NNNN`
- `aceita, estendida pela NNNN`

O texto original **não é editado** nos dois casos. Ele continua contando o raciocínio da época, que é o que torna a série uma linha do tempo em vez de um retrato do presente.

### `Status` e `Validação` são eixos diferentes

`Status` responde **"isto me vincula?"**. Se a decisão já foi provada rodando é outra pergunta, e misturar as duas no mesmo campo torna impossível responder a primeira sem ler todas as variantes da segunda.

**Validação possíveis:** `em execução`, `não validada`, `parcial`.

O campo é **opcional, e só aparece quando a decisão faz uma afirmação que a execução pode confirmar ou desmentir** — "o self-healing conserta em 50s" é dessas; "o ECR mora no `bootstrap`" não é. Ausente significa que não há o que validar, não que ninguém testou.

### Correção factual não é decisão superada

Um erro de fato no texto — número errado, citação torta, nome de recurso que nunca existiu — **é corrigido no lugar**, sem nota e sem superar nada. A imutabilidade protege *o raciocínio da época*, não um erro de leitura.

O teste é: se a frase corrigida muda **o que foi decidido ou por quê**, é decisão superada e vale a nota no topo. Se muda só o que é verdade sobre o mundo, é correção.

### Quando uma ADR carrega mais que a decisão

As linhas acima dizem que narrativa vai para `docs/desafios/` de cada repositório. Algumas ADRs desta série desobedecem de propósito, carregando uma seção de achados de execução — o que só se descobriu aplicando.

Isso acontece quando **não existe documento de desafio para aquele assunto** e o achado se perderia. É desvio consciente, não descuido. Quando o desafio existir, o achado migra e a ADR fica com o link.

---

## Por domínio

### Kubernetes e GitOps

| # | Decisão | Status |
|---|---|---|
| [0001](0001-chart-de-terceiros-como-wrapper.md) | Chart de terceiros entra como dependência de um chart nosso | aceita |
| [0002](0002-um-chart-por-componente.md) | Um chart e uma Application por componente de plataforma | aceita |
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform | aceita |
| [0020](0020-tag-da-imagem-e-o-sha.md) | A tag da imagem é o SHA, e o CD escreve no GitOps | aceita |
| [0025](0025-baseline-em-spot.md) | Baseline em dois nós spot, com cinco tipos de instância | aceita |

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
| [0023](0023-datadog-como-codigo.md) | O que é construído no Datadog vira Terraform, num stage próprio | aceita, exceto no destroy |
| [0024](0024-encaixe-do-stage-datadog-na-esteira.md) | Plan do stage `datadog` na matriz, apply em esteira própria | aceita, estendida |
| [0025](0025-baseline-em-spot.md) | Baseline em dois nós spot, com cinco tipos de instância | aceita |
| [0027](0027-ciclo-de-vida-do-stage-datadog.md) | O stage `datadog` sobe com o ambiente e é destruído primeiro | aceita |
| [0033](0033-pagerduty-em-stage-proprio.md) | Stage `pagerduty` próprio, para a chave não atravessar fronteira | aceita |

### Observabilidade

| # | Decisão | Status |
|---|---|---|
| [0003](0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform | aceita |
| [0004](0004-collector-no-meio.md) | Collector entre as aplicações e os backends | aceita |
| [0005](0005-datadog-como-apm.md) | Datadog como APM | aceita |
| [0007](0007-permanecer-em-go-1-25.md) | A linha 1.47 do OTel exige Go 1.26: fica tudo em OTel 1.46 | aceita |
| [0008](0008-padrao-de-resource-attributes.md) | Padrão de resource attributes | aceita |
| [0009](0009-caminho-dos-logs.md) | Log por OTLP no local, stdout mais `filelog` em produção | aceita |
| [0010](0010-amostragem-em-100.md) | Amostragem de traces em 100% | aceita |
| [0011](0011-go-redis-v8-para-v9.md) | `go-redis` para a v9, único caminho para instrumentar o cache | aceita |
| [0021](0021-api-key-do-datadog-por-tf-vars.md) | A API key do Datadog por `tf-vars` | aceita |
| [0022](0022-datadog-connector-desde-o-inicio.md) | O `datadog/connector` junto do exporter | aceita |
| [0023](0023-datadog-como-codigo.md) | O que é construído no Datadog vira Terraform, num stage próprio | aceita, exceto no destroy |
| [0026](0026-sem-dashboard-no-datadog.md) | Não haverá dashboard customizado no Datadog | aceita |
| [0027](0027-ciclo-de-vida-do-stage-datadog.md) | O stage `datadog` sobe com o ambiente e é destruído primeiro | aceita |
| [0028](0028-slack-para-chatops.md) | Slack para o ChatOps, aceitando um passo manual de OAuth | aceita |
| [0029](0029-dois-golden-signals.md) | Latência e taxa de erro; tráfego e saturação ficam como lacuna | aceita |
| [0030](0030-self-healing-em-github-action.md) | O self-healing roda numa GitHub Action, não numa Lambda | aceita, estendida pelas 0031 e 0032 |
| [0031](0031-self-healing-mora-no-iac.md) | O self-healing mora no `togglemaster-iac`, sem repositório novo | aceita |
| [0032](0032-triagem-por-sondas-e-report-no-slack.md) | O Datadog notifica; a Action triagem por sondas, remedia e reporta | aceita |
| [0033](0033-pagerduty-em-stage-proprio.md) | PagerDuty como código, num stage próprio com as duas pontas da integração | aceita |
| [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md) | Aviso em 5% e crítico em 10%, com janela de confirmação antes de remediar | aceita |

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
| [0024](0024-encaixe-do-stage-datadog-na-esteira.md) | Plan do stage `datadog` na matriz, apply em esteira própria | aceita, estendida |
| [0027](0027-ciclo-de-vida-do-stage-datadog.md) | O stage `datadog` no apply e no destroy | aceita |
| [0030](0030-self-healing-em-github-action.md) | A remediação executa numa Action disparada por `repository_dispatch` | aceita, estendida |
| [0031](0031-self-healing-mora-no-iac.md) | O workflow de self-healing no `togglemaster-iac`, sem repositório novo | aceita |
| [0032](0032-triagem-por-sondas-e-report-no-slack.md) | Filtro de transição, disjuntor por ciclo de alerta e report no Job Summary | aceita |
| [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md) | Janela de confirmação re-sondando antes de remediar, com o tempo em variável | aceita |

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
| [0026](0026-sem-dashboard-no-datadog.md) | Sem dashboard customizado no Datadog | 16/10 |
| [0027](0027-ciclo-de-vida-do-stage-datadog.md) | Ciclo de vida do stage `datadog` | 16/10 |
| [0028](0028-slack-para-chatops.md) | Slack para o ChatOps | 16/10 |
| [0029](0029-dois-golden-signals.md) | Dois golden signals, e as duas lacunas | 16/10 |
| [0030](0030-self-healing-em-github-action.md) | Self-healing em GitHub Action | 22/10 |
| [0031](0031-self-healing-mora-no-iac.md) | O self-healing mora no `togglemaster-iac` | 22/10 |
| [0032](0032-triagem-por-sondas-e-report-no-slack.md) | Triagem por sondas, e o Datadog notificando em paralelo | 22/10 |
| [0033](0033-pagerduty-em-stage-proprio.md) | PagerDuty como código, num stage próprio | 27/10 |
| [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md) | Escada de severidade, e espera antes de remediar | 30/10 |

As três últimas são da **rodada 3** — Datadog, alerta, PagerDuty, Slack e self-healing.

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
2. Preencha `Domínio` e `Fase` no cabeçalho, e `Validação` se houver o que validar
3. Preencha contexto, decisão, **alternativas descartadas** e consequências
4. Acrescente nas tabelas por domínio — **uma linha por domínio declarado** — e na da fase
5. Se superar uma decisão existente, marque a antiga como `superada por NNNN` — **não apague**
6. Rode [`./verificar.sh`](verificar.sh)

### Por que as tabelas são escritas à mão

Porque a descrição de cada linha diz por que aquela decisão importa **para aquele domínio**, e isso não sai do título. A [0032](0032-triagem-por-sondas-e-report-no-slack.md) é o exemplo: em Observabilidade ela é *"o Datadog notifica; a Action tria por sondas, remedia e reporta"*; em CI/CD é *"filtro de transição, disjuntor por ciclo de alerta e report no Job Summary"*. Gerar as tabelas a partir do título achataria as duas na mesma frase.

O preço disso é deriva, e ela já aconteceu: a 0027 ficou fora de ordem na tabela de Observabilidade e ninguém viu; três ADRs declaravam um domínio em que não apareciam. O `verificar.sh` é o que cobra o preço — ele confere o campo `Domínio` contra as tabelas nos dois sentidos, a ordem numérica, a cobertura, o vocabulário de `Status` e `Validação`, e os links. Sai `1` em qualquer divergência, então serve de passo de esteira.
