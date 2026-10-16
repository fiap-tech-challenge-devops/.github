# 0028 — Slack para o ChatOps, aceitando um passo manual de OAuth

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 16/10/2026 · **Fase:** 4

## Contexto

O enunciado pede **ChatOps**: "notificação detalhada em canal do Slack, Discord ou Teams". A escolha parecia de gosto e não é — ela muda a arquitetura, porque **o Datadog não tem integração nativa com Discord.**

Procurando, não há documentação oficial de um handle `@discord`. O que existe são plataformas terceiras fazendo a ponte. As integrações nativas são Slack e Microsoft Teams.

| | Slack | Discord |
|---|---|---|
| Como chega | integração nativa, `@slack-canal` na mensagem do monitor | `datadog_webhook` com payload montado à mão |
| A mensagem | pronta, **com snapshot do gráfico** | você constrói o JSON |
| Pré-requisito | **admin do workspace autoriza por OAuth** | criar webhook no canal, sem admin |
| Em Terraform | `datadog_integration_slack_channel`, depois de conectado | 100%, sem OAuth |

## Decisão

**Slack**, pela integração nativa.

## Alternativas descartadas

**Discord por webhook.** Tecnicamente mais coerente com a [0023](0023-datadog-como-codigo.md) do que a opção escolhida: sendo `datadog_webhook`, seria **100% Terraform, sem OAuth e sem depender de admin de workspace**. Conta nova de trial seria reconstruída inteira por apply.

Descartada porque a mensagem é artesanal e **não traz snapshot do gráfico** — e o snapshot é um dos prints que o relatório pede, além de ser o que torna a notificação "detalhada" no sentido que o enunciado usa. Construir um embed à mão que chegue perto disso é trabalho com pouco retorno.

**Microsoft Teams.** Também nativo, mesma categoria do Slack. Descartado por não haver workspace de Teams no grupo.

## Consequências

- **Sobra um passo manual que o Terraform não cobre:** alguém com permissão de admin precisa autorizar o app do Datadog no workspace do Slack, por OAuth. Só depois disso o `datadog_integration_slack_channel` funciona
- Esse passo entra na lista de **pré-requisitos manuais documentados**, junto do provedor OIDC e da role de CI da [0015](0015-oidc-sem-chave-estatica.md) — e pelo mesmo motivo de fundo: OAuth existe para não ser automatizável
- **A reprodutibilidade por apply, que a 0023 buscava, fica com um buraco.** Conta nova de Datadog exige reconectar o Slack à mão antes de o apply funcionar. É um passo, documentado, e não é evitável com integração nativa de nenhum fornecedor
- **O passo tem latência que não está nas nossas mãos.** Depende de alguém com admin do workspace. Vale começar cedo, pelo mesmo raciocínio que levou a criar a conta Datadog antes de tudo
- Se o Slack se mostrar inviável por permissão, o Discord continua disponível como caminho de recuo — e o registro acima diz exatamente o que se ganha e se perde na troca

## Onde aprofundar

Hub de [observabilidade](../observabilidade/README.md)
