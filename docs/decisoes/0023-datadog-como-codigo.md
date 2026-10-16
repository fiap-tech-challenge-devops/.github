# 0023 — O que é construído no Datadog vira Terraform, num stage próprio

**Status:** aceita, **exceto no ponto do destroy, superado pela [0027](0027-ciclo-de-vida-do-stage-datadog.md)** · **Domínio:** IaC · Observabilidade · **Data:** 15/10/2026 · **Fase:** 4

> **O que mudou:** esta decisão manteve o `datadog` fora da cadeia de destroy, para preservar o histórico de disparo dos monitores. O argumento não resiste a este projeto — num ambiente destruído toda noite esse histórico tem horas —, e monitor sobrevivente fica observando ambiente morto e disparando por no-data. A 0027 inverte esse ponto.
>
> **E isso derruba um dos argumentos desta decisão.** O stage separado foi justificado, entre outras coisas, por **ciclo de vida independente**. A 0027 acoplou os ciclos: o Datadog passa a ser destruído junto com o ambiente. Quem ler só a seção "Alternativas descartadas" abaixo vai encontrar esse argumento ainda escrito.
>
> **A separação continua certa**, por quatro razões que sobrevivem — e a mais forte nasceu depois: se o Datadog estivesse dentro do `infra`, uma key de trial expirada faria o `terraform destroy` do `infra` **falhar inteiro**, porque erro de configuração de provider derruba o plano todo. O ambiente AWS ficaria sem poder ser destruído, custando. Só com stages separados dá para tolerar essa falha, que é o que o `if` do `addons` faz.
>
> Somam-se: provider e credencial diferentes, que o `infra` passaria a exigir; o raio do plan, para mudança de monitor não planejar VPC, EKS e três bancos; e a ordem no destroy, que num stage único o grafo do Terraform não teria como saber.

## Contexto

A [0021](0021-api-key-do-datadog-por-tf-vars.md) tornou a **conta** trocável: key e site vivem num segredo, e mudar de conta é alterar um secret e rodar o apply.

Isso cobre o caminho do dado. Não cobre o que é construído em cima dele — monitor de 5xx, integração com PagerDuty, integração com Slack, dashboards. Tudo isso é clique no painel, e portanto:

- **Morre com a conta.** O trial expira, a conta nova nasce vazia, e tudo é refeito à mão
- **Não é revisável.** Ninguém aprova um limiar de alerta em PR, e mudar de 5% para 10% não deixa rastro
- **Não é reproduzível.** A demonstração do vídeo depende de um estado que só existe num painel

É o mesmo problema que fez o dashboard do Grafana ser JSON versionado em vez de desenho na tela.

## Decisão

**O que for construído no Datadog é gerenciado pelo provider Terraform do Datadog** — `datadog_monitor`, `datadog_integration_pagerduty`, `datadog_integration_slack_channel`, `datadog_dashboard_json`.

> O `datadog_dashboard_json` **não será usado**: a [0026](0026-sem-dashboard-no-datadog.md) decidiu que não há dashboard customizado no Datadog, porque o enunciado pede o dashboard no Grafana e as páginas nativas de APM já cobrem o que se pretendia construir.

**E mora num stage novo, `datadog/`, com state próprio.**

## Alternativas descartadas

**No `infra` ou no `addons`.** Descartada por um fato, não por preferência: **os dois são destruídos toda noite** pelo agendamento do `iac-destroy` (`addons → infra`, 04:00 UTC). Monitor ali seria apagado e recriado diariamente — perdendo histórico de disparo e, pior, podendo re-notificar a cada recriação.

**No `bootstrap`.** É o stage que sobrevive ao ambiente, e aqui o argumento da [0013](0013-ecr-no-bootstrap.md) **de fato se aplica** — ao contrário do segredo da API key, onde eu argumentei que não. A distinção é o que importa:

| | O segredo da key | Um monitor |
|---|---|---|
| Onde o valor vive de verdade | GitHub Secrets | No Datadog |
| Recriar custa | nada | histórico de disparo e possível re-notificação |

Mesmo assim, descartada por **cadência** — o mesmo critério da [0003](0003-observabilidade-no-gitops.md). Monitor e dashboard mudam toda semana durante a fase; o `bootstrap` provisiona o bucket de state e os repositórios ECR, e é aplicado raramente e à mão. Não se mistura apply semanal com o stage que fundamenta todos os outros.

Somam-se duas separações limpas que um stage próprio dá de graça: **provider diferente** (nenhum recurso AWS) e **credencial diferente** (API key e Application key do Datadog, não federação OIDC).

**Os CRDs do Datadog Operator.** A alternativa mais forte, e a que mais combinaria com este projeto. O Operator expõe `DatadogMonitor` e `DatadogDashboard` como recursos do Kubernetes: o monitor moraria no repositório GitOps, sincronizado pelo Argo CD, igual a todo o resto — sem stage novo, sem state novo, e com a credencial entrando por External Secrets, padrão que já existe. O Argo daria drift detection e self-heal de graça, que é o principal argumento do Terraform.

Descartada por três motivos, em ordem de peso:

**Ela vive no cluster, e o cluster é destruído toda noite.** Se apagar o CR apaga o monitor no Datadog, os monitores somem e voltam diariamente — exatamente o problema que descartou o `addons`. *Este comportamento não foi confirmado na documentação do Operator*, e é o único fato que poderia reabrir a decisão.

**Não cobre webhook nem integrações.** Não há CRD para PagerDuty, Slack ou `datadog_webhook`. Como o self-healing depende de webhook, o Operator obrigaria a **duas ferramentas de todo modo** — CRD para monitor e dashboard, Terraform ou painel para o resto. O Terraform cobre a superfície inteira com uma.

**`DatadogDashboard` é `v1alpha1`** e exige Operator v0.6+. API imatura numa peça que precisa funcionar na demonstração.

**Construir na mão e documentar com prints.** Atenderia o enunciado, que pede evidência e não código. Descartada porque perde tudo na expiração do trial — e a expiração é certa, não hipótese.

## Consequências

- **Stage novo na esteira**, com encaixe próprio — ver [0024](0024-encaixe-do-stage-datadog-na-esteira.md). **Fica fora do `iac-destroy.yml`**, e isso é o ponto, não um esquecimento
- **Uma credencial nova:** o provider exige *Application key* além da API key. Ela ainda não existe, e entra pelo mesmo caminho da 0021 — `tf-vars`, e o valor acompanha a conta no mesmo segredo
- **O stage só pode ser aplicado depois que a telemetria flui.** Monitor referencia métrica que só existe quando o Collector exporta, então a ordem é 3.1 → `datadog/`
- O limiar do alerta passa a ser revisável em PR, e o `git log` do stage conta quando cada monitor mudou
- A conta nova é reconstruída por apply, não por memória

## O que isto não resolve

**A conexão entre contas é OAuth, e OAuth não se automatiza.** O provider gerencia o que é construído *sobre* uma conexão existente, não a conexão:

| Peça | Terraform? |
|---|---|
| Monitor, dashboard | sim |
| Canal do Slack que recebe o alerta | sim, **se** o workspace já estiver conectado |
| Autorizar o Datadog no workspace do Slack | **não** — OAuth no painel |
| Serviço no PagerDuty e sua integration key | não pelo provider do Datadog; manual, ou o provider do PagerDuty |

Sobra um **núcleo manual irredutível**: conectar as contas. Ele vale estar documentado como pré-requisito, do mesmo jeito que o provedor OIDC e a role de CI estão na [0015](0015-oidc-sem-chave-estatica.md) — e pelo mesmo motivo, que é circularidade e não conveniência.

## Uma rede de segurança que compõe com isto

O **`datadog-sync-cli`**, ferramenta oficial do Datadog, copia recursos entre organizações — dashboards, monitores e mais de 30 tipos. O Datadog a documenta no contexto de *disaster recovery*.

Ela **não** é alternativa a esta decisão: não dá revisão em PR, não dá diff de limiar, não detecta drift, e cada sync sobrescreve o destino. Mas é a resposta mais direta para "o trial morreu amanhã" e funciona junto com qualquer escolha. Vale conhecer antes de precisar.

## Onde aprofundar

Hub de [observabilidade](../observabilidade/README.md) e o [IaC](../iac/README.md)
