# 0030 — O self-healing roda numa GitHub Action, não numa Lambda

**Status:** aceita, **estendida pelas [0031](0031-self-healing-mora-no-iac.md) e [0032](0032-triagem-por-sondas-e-report-no-slack.md)** · **Domínio:** Observabilidade · CI/CD · **Validação:** em execução · **Data:** 22/10/2026 · **Fase:** 4

## Contexto

O enunciado pede automação que reaja ao alerta, disparada por webhook. O monitor existe e dispara — validado em 22/10 com o [roteiro de incidente](../observabilidade/roteiro-de-incidente.md). Falta decidir **onde a lógica executa**.

A decisão foi adiada de propósito até o alerta disparar de verdade, para ser tomada com o cenário conhecido em vez de suposto. E isso mudou a resposta.

**A remediação não opera o Git.** Ela opera AWS e Kubernetes:

```
1. aws secretsmanager update-secret-version-stage   ← reverte a rotação
2. kubectl annotate externalsecret ... force-sync   ← propaga
3. kubectl delete pod                               ← recarrega o ambiente
```

Uma avaliação anterior favorecia a Action porque a remediação cogitada era `git revert` de um commit no GitOps. Aquele cenário foi descartado — reverter cego confunde o troubleshooting, e a prática não o lista entre as remediações automatizadas. Com ele caiu também o argumento que sustentava a escolha.

## Decisão

**GitHub Action**, acionada por `repository_dispatch` a partir do webhook do Datadog.

## Alternativas descartadas

**Lambda com Function URL.** Genuinamente competitiva, e melhor em dois pontos: a role de execução dispensa assumir credencial para chamar a AWS, e a latência é de segundos contra os ~30s de fila e boot de runner. A lógica também ficaria em linguagem testável em vez de bash.

Descartada porque **ela participaria do ciclo de vida do ambiente**. Vivendo no `infra` ou no `addons`, seria destruída toda noite, e a URL — que contém um identificador gerado — mudaria a cada reconstrução. O webhook do Datadog passaria a apontar para um endereço morto.

Isso é contornável com a URL publicada no SSM e lida pelo stage `datadog`, no mesmo padrão da [0012](0012-tres-stages-de-terraform.md). Mas criaria um acoplamento que a [0027](0027-ciclo-de-vida-do-stage-datadog.md) evitou de propósito: o job `datadog` roda **sem `needs:`**, em paralelo com o `infra`. Numa reconstrução ele poderia aplicar antes de a Lambda existir, e religá-los exigiria a dependência que aquela decisão recusou.

**O princípio que decide:** a automação de recuperação não deveria depender daquilo que ela recupera. Num projeto cujo ambiente passa a maior parte do tempo destruído, manter a automação fora dele é o que a torna confiável.

**PagerDuty Runbook Automation.** É a opção que o enunciado cita primeiro. Descartada por ser produto separado, provavelmente fora do free tier, e por encadear a correção **depois** do roteamento do incidente — disparando em paralelo a partir do Datadog, a correção começa enquanto o humano ainda está sendo acordado.

## O que já existe e não precisa ser construído

Verificado em 22/10:

| Peça | Situação |
|---|---|
| Role `github-actions-iac` | já assumida por OIDC pelas esteiras |
| Permissão na AWS | `AdministratorAccess` — cobre o Secrets Manager |
| **Access entry no EKS** | **já existe** para essa role — `kubectl` funciona |
| Endpoint do EKS | público, sem restrição de CIDR |

A Action alcança AWS e cluster **sem nenhuma permissão nova**.

## Consequências

- **Um PAT do GitHub fica guardado no Datadog**, com escopo de `repository_dispatch`. É credencial de longa duração fora do controle da IaC, e entra na lista de pré-requisitos manuais ao lado do provedor OIDC, da role e do OAuth do Slack — ver [0015](0015-oidc-sem-chave-estatica.md)
- Ele **morre com o trial**: conta nova do Datadog exige recriar o webhook e colar o PAT de novo
- **O log da execução é o artefato do relatório.** O enunciado exige evidência da execução do self-healing, e o log de uma Action já sai legível e carimbado, sem montagem
- Latência de ~30s entre o webhook e o início da remediação, por fila e boot de runner. Irrelevante para este caso; seria relevante para remediação de segundos
- A automação **sobrevive ao destroy**, porque não é infraestrutura AWS

## O que a escolha custou e rendeu, medido

A cadeia rodou de ponta a ponta em 23/10: alerta → webhook → `repository_dispatch` → diagnóstico → remediação → verificação, em **50 segundos**. Detalhe na [0032](0032-triagem-por-sondas-e-report-no-slack.md).

Isso ajusta duas previsões desta decisão:

**A latência de ~30s estimada ficou em ~12s** entre o webhook e a primeira sonda. O boot do runner é mais rápido do que eu supunha, e o total de 50s é dominado pela remediação — reciclar dois pods em série —, não pela fila.

**O log como artefato se confirmou, mas o Job Summary é melhor.** A previsão era que o log da Action bastaria como evidência. Na prática a tabela renderizada no `$GITHUB_STEP_SUMMARY` é o que se mostra; o log serve para depurar. A diferença importa porque o enunciado pede evidência de execução, e uma tabela carimbada vale mais que linhas de `echo`.

## O que esta decisão não resolve

**Em qual repositório o workflow mora.** Resolvido pela [0031](0031-self-healing-mora-no-iac.md): `togglemaster-iac`.

**As salvaguardas.** Resolvidas pela [0032](0032-triagem-por-sondas-e-report-no-slack.md) — triagem por sondas de leitura, reproduzir antes de remediar, filtro de transição e disjuntor por ciclo de alerta.

**O PagerDuty.** Segue fora por escolha, e é a única peça do enunciado sem nada construído.

## Onde aprofundar

[Roteiro de incidente](../observabilidade/roteiro-de-incidente.md) e o hub de [CI/CD](../ci-cd/README.md)
