# 0031 — O self-healing mora no `togglemaster-iac`, sem repositório novo

**Status:** aceita · **Domínio:** CI/CD · Observabilidade · **Data:** 22/10/2026 · **Fase:** 4

## Contexto

A [0030](0030-self-healing-em-github-action.md) decidiu que a remediação roda numa GitHub Action e deixou aberto **em qual repositório ela mora**. A pergunta chegou mais larga do que o workflow: o gerador de tráfego da demonstração também não é Terraform, e a sensação era de que havia uma categoria de artefatos sem casa — operacionais, não de aplicação nem de infraestrutura.

Três candidatos: ficar no `togglemaster-iac`, criar um repositório novo, ou reviver o `togglemaster-platform-legacy`, que está dormente desde a Fase 2.

**Antes de escolher a casa, valia checar se os artefatos estão de fato desabrigados.** Não estão. As três dependências da remediação moram no `togglemaster-iac`:

| Dependência | Onde está |
|---|---|
| Role assumida por OIDC | `github-actions-iac`, usada pelas esteiras do repositório |
| Acesso ao cluster | access entry dessa role no `eks-togglemaster` |
| O segredo que a remediação reverte | `togglemaster/app/evaluation`, criado pelo stage `infra` |

O que puxava para o `togglemaster-gitops` era estético — *"ela age sobre as aplicações"*. Mas ela age por `kubectl delete pod`, operação de cluster, não mudança de manifest. Se algum dia a remediação precisasse alterar manifest, aí seria commit no GitOps, e um desenho diferente: o repositório precisaria de permissão de escrita em si mesmo.

**Um argumento da 0030 não serve aqui, e vale registrar para não ser mal lido depois.** *"A automação fica fora do ciclo de vida do ambiente"* é sobre **state do Terraform**, não sobre repositório: um arquivo em `.github/workflows/` não é destruído por `terraform destroy` em nenhum dos três candidatos. Aquele argumento decidiu Action contra Lambda; ele não decide onde a Action mora.

## O fato que decidiu

A trust policy da role `github-actions-iac`, consultada em 22/10:

```
repo:fiap-tech-challenge-devops*/togglemaster-iac*
repo:fiap-tech-challenge-devops*/togglemaster-platform*
```

E essa trust policy **não está no Terraform.** O `local.services` do `bootstrap` cobre os cinco microsserviços e alimenta a role `github-actions-ecr-push`; a `github-actions-iac`, com `AdministratorAccess`, é o pré-requisito manual descrito em [`desafios/04`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/docs/desafios/04-ecr-publico-anonimo.md) — *"o que fica fora da IaC também fica fora da auditoria"*.

Logo: um repositório com nome fora desses dois padrões exige **editar à mão a role mais privilegiada do projeto**, aprofundando exatamente a lacuna registrada como lição aprendida uma semana antes.

## Decisão

O workflow de self-healing vive em **`togglemaster-iac/.github/workflows/self-healing.yml`**. O gerador de tráfego permanece em `scripts/demo/`. Nenhum repositório novo.

Duas mitigações, porque a deriva é real:

- o `README.md` do repositório declara o que ele guarda **além** de Terraform
- o workflow **não** leva o prefixo `iac-`, reservado às esteiras de stage, para ninguém confundir remediação com `plan`/`apply`/`destroy`

## Alternativas descartadas

**Repositório novo — `togglemaster-ops`.** Estruturalmente a mais limpa, e a resposta certa quando o artefato tem ciclo de vida próprio, revisores próprios, cadência de release própria, ou precisa sobreviver à destruição daquilo que opera. Nenhuma dessas condições vale aqui.

Descartada pelo custo em IAM acima, e por um custo de navegação: seria o 12º repositório da organização para abrigar um workflow e um script. Num projeto avaliado por leitura, repositório a mais é superfície a mais para o avaliador atravessar.

**Reviver o `togglemaster-platform-legacy`.** Mais tentadora do que parecia: o wildcard `togglemaster-platform*` já está na trust policy, então o custo em IAM seria **zero** — e o repositório já tem `scripts/` e `otel/`.

Descartada porque aquele repositório **é a evidência das Fases 1 e 2** — `docker-compose.yml`, `docker-compose.ecr.yml`, `.env.example`. Hoje ele faz um trabalho só, e o faz limpo: ser o registro histórico. Misturar automação viva de Fase 4 nele estraga a única coisa que ele faz bem. E renomeá-lo para `togglemaster-platform` faria o relatório afirmar que o repositório do ambiente local das fases iniciais executa remediação em produção — os redirects do GitHub seguram os links, mas a contradição de nome fica.

**Mover o gerador de tráfego.** Rejeitada por ganho nulo: ele descobre o ALB por `kubectl`, exercita o ambiente provisionado, está documentado e mergeado. Mover custaria atualização de links e nada mais.

## Consequências

- O `togglemaster-iac` **deixa de ser um repositório só de Terraform**, e isso precisa estar escrito no README dele em vez de descoberto por quem abre a pasta
- **O gatilho de reavaliação é quantitativo:** três ou mais workflows operacionais, ou um conjunto de scripts com dependências próprias. Até lá, não dói
- **Postergar não custa.** O custo de extrair — trust policy, secrets de Action, ruleset — é o mesmo hoje e em dois meses; ele não cresce com o acúmulo. Por isso "extrair quando doer" é a regra correta aqui, e não procrastinação
- Os secrets de Action continuam num lugar só. Repositório novo exigiria recriar `AWS_OIDC_ROLE_ARN_VITAO` e conviver com duas cópias divergindo

## O que esta decisão não resolve

**As salvaguardas da remediação**, que seguem abertas desde a [0030](0030-self-healing-em-github-action.md): diagnosticar antes de agir, limitar tentativas por incidente, escalar em vez de insistir. São o que separa remediação de um script que reinicia pod.

**O nome do stage `datadog`.** Ele vai receber `datadog_integration_pagerduty` e `datadog_integration_slack_channel`, que são recursos Datadog legítimos. Mas se um dia entrar provider do PagerDuty puro — serviços, escalation policies —, o nome do stage passa a descrever menos do que ele contém. Fica anotado, não decidido.

## Onde aprofundar

[0030](0030-self-healing-em-github-action.md) para o porquê da Action · [0012](0012-tres-stages-de-terraform.md) para a divisão de stages · o hub de [CI/CD](../ci-cd/README.md)
