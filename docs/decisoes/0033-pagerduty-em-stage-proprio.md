# 0033 — PagerDuty como código, num stage próprio

**Status:** aceita, validada em execução · **Domínio:** Observabilidade · IaC · **Data:** 27/10/2026 · **Fase:** 4

## Contexto

A [0032](0032-triagem-por-sondas-e-report-no-slack.md) deixou o PagerDuty de fora por escolha, e ele era a única peça do enunciado sem nada construído. Entrando, duas perguntas: **o que acorda alguém** e **onde os recursos moram**.

Um argumento meu foi descartado logo no início, e vale registrar por ter sido fraco: propus criar serviço e escalation policy **à mão**, porque o tier gratuito permite um de cada e "não há o que gerenciar". É argumento de conveniência, e contraria o princípio que a [0023](0023-datadog-como-codigo.md) já estabeleceu. O que sustenta fazer como código aqui não é reconstruir a conta — o plano gratuito do PagerDuty **não expira**, diferente do trial do Datadog — e sim ter o ambiente inteiro reproduzível e auditável.

## O que acorda alguém

**Os oito monitores.** Escolha deliberada, para a demonstração em vídeo, com a consequência aceita: o incidente do `evaluation-service` abre e **resolve sozinho em poucos minutos**, porque o self-healing conserta em 50 segundos e o monitor recupera depois. Quem for acordado encontra "já resolvido".

Foram consideradas duas alternativas mais defensáveis para o dia a dia:

**Paginar só o que não tem remediação.** Simples, mas deixa uma lacuna: se a Action falhar, ninguém acorda — justamente porque o monitor do `evaluation` é o que tem automação.

**Dois níveis.** Nível 1 em `last_5m` para Slack e remediação; nível 2 em `last_15m` com limiar ~50% para o PagerDuty, significando *"a automação não deu conta"*. A matemática separa os casos: remediado, a razão sobre 15 minutos chega a ~27% e nunca cruza; não remediado, passa de 50% por volta dos 7,5 minutos. Implementaria literalmente a salvaguarda *"escalar em vez de insistir"* que a [0030](0030-self-healing-em-github-action.md) listou.

Ficam registradas como o desenho correto para operação real. A escolha atual é de demonstração, e isso está dito.

> **Atualização, 30/10:** o desenho de dois níveis acima foi **descartado** pela [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md). A matemática daqui olhou só a subida e esqueceu a descida: a janela de `last_15m` leva quinze minutos para drenar, então o nível 2 ficaria em alerta por mais de dez minutos **depois** de o self-healing curar — acordando o plantão para um incidente resolvido, que é o ruído que esta seção queria evitar. O que entrou no lugar foi uma escada de severidade no mesmo monitor e na mesma janela, que recupera junto com a falha.

## Onde os recursos moram

**Stage próprio `pagerduty/`, com as duas pontas da integração.**

A restrição que definiu a forma: o stage `datadog` **não declara provider AWS nem lê SSM** — conversa só com a API do Datadog. Isso lhe dá uma propriedade concreta: o `Plan (datadog)` funciona com o ambiente destruído, que é o estado normal fora do horário de uso.

Só um recurso precisa da chave da integração:

| Recurso | Precisa de | Stage |
|---|---|---|
| `pagerduty_service_integration` | — | `pagerduty/` |
| `datadog_integration_pagerduty_service_object` | a **key** | `pagerduty/` |
| mensagem do monitor `@pagerduty-<serviço>` | só o **nome** | `datadog/` |

A chave nunca atravessa fronteira. O handle é derivado de `service_namespace` e `environment` nos dois lados — a mesma string, sem indireção.

**Sem schedule.** O tier gratuito permite um só, e a escalation policy aponta direto para o usuário. Isso também faz a configuração **sobreviver ao fim do trial**: 1 escalation policy e 0 schedules cabem no plano gratuito.

**`data` e não `resource` para o usuário.** Criar e destruir usuário a cada apply dispararia convite por e-mail toda noite.

## Alternativas descartadas

**Passar a chave por SSM**, no padrão da [0012](0012-tres-stages-de-terraform.md). É o jeito estabelecido no projeto, e por isso foi a primeira ideia. Descartada porque o parâmetro morreria no destroy noturno junto com o stage, e aí **todo PR aberto com o ambiente fora teria `Plan (datadog)` vermelho** — o estado normal do repositório. É o mesmo acoplamento que a [0027](0027-ciclo-de-vida-do-stage-datadog.md) evitou e que a [0030](0030-self-healing-em-github-action.md) usou para descartar a Lambda.

**Tudo no stage `datadog/`.** Zero trabalho estrutural, mas o nome passaria a descrever menos do que o stage contém — a deriva que a [0031](0031-self-healing-mora-no-iac.md) deixou anotada.

**Renomear o stage para `observability/`** e juntar tudo. Combinaria com o vocabulário do projeto — o hub da documentação e o namespace no cluster têm esse nome. Descartada por um risco de leitura: a [0003](0003-observabilidade-no-gitops.md) decidiu que a **stack** de observabilidade vive no GitOps, e um stage de Terraform com esse nome sugere o contrário.

**`bootstrap/`**, pelo ciclo de vida: configuração de plantão pertence ao time, não ao ambiente, e o `bootstrap` não entra no destroy. Descartada em favor da reprodutibilidade total — o stage sobe e cai com o resto, e a integração continua coerente porque as duas pontas são recriadas juntas. O que se perde é histórico de incidentes e de plantão, irrelevante num projeto sem plantão real.

## Dois achados que só a execução revelou

**O `api_token` é "opcional" no schema e obrigatório na prática.** Removi por achar que servia só para o Datadog ler schedules, que não usamos — a API recusou com `{"errors":["The integration is not installed"]}`. Ele é o que **instala** a integração na conta. A tentativa de reduzir superfície de credencial estava certa em princípio e errada em fato, e o jeito de saber era aplicar.

**O `data.pagerduty_user` compara byte a byte.** O código do provider tem o `strings.EqualFold` — que ignoraria maiúsculas — **comentado logo acima** da comparação exata. Qualquer diferença de um caractere falha.

Isso casou com outra coisa: o parser do `tf-vars` no `reusable-workflows` **não apara espaço nem `\r`**. Um espaço invisível no fim da linha do secret produziu `Unable to locate any user with the email`, e a causa ficou a duas camadas de distância do sintoma.

## Consequências

- **O job `datadog` ganhou `needs: pagerduty` com `if: ${{ !cancelled() }}`** — ordem sem veto. Duas execuções seguidas tiveram os monitores pulados por uma falha num stage de SaaS que não custa nada nem derruba nada. O `iac-destroy` já usava esse par; o apply não, e devia
- **Destroy em `datadog → pagerduty → addons → infra`**, com a mesma tolerância: nenhum stage de SaaS pode segurar a destruição do que custa dinheiro
- **`pagerduty_habilitado` desligado por padrão.** Sem a conta configurada, nada muda nos monitores
- **O parser do `tf-vars` continua sem aparar**, por decisão. A correção exigiria release no `reusable-workflows` e bump de tag nos chamadores; fica como lacuna conhecida, com o sintoma documentado em [`variaveis-e-segredos.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/docs/variaveis-e-segredos.md)
- **Um destroy disparado da `main` antes do merge não derrubou o PagerDuty**, porque o job só existia na branch. `workflow_dispatch` executa a versão do workflow do ref escolhido — vale lembrar quando um stage novo ainda não entrou

## Validação

27/10, com o ambiente de pé e tráfego rodando:

```
18:00 UTC   monitor dispara
            ├─→ incidente #1 no PagerDuty, serviço togglemaster-prod
            └─→ webhook → self-healing, ciclo 8872818031580611215, success
```

Os dois caminhos em paralelo, sem um orquestrar o outro — o desenho da [0032](0032-triagem-por-sondas-e-report-no-slack.md) confirmado com o PagerDuty dentro.

## O que esta decisão não resolve

**O fechamento automático do incidente.** O esperado é que o Datadog mande o `resolve` quando o monitor recuperar. É o comportamento documentado da integração e ainda não foi observado aqui. Se não acontecer, cada quebra deixa incidente aberto, e em semanas o Console vira ruído — o mesmo mecanismo pelo qual se aprende a ignorar um alerta.

**Se o Datadog recusa um monitor que cita um handle inexistente.** A pergunta ficou acadêmica quando o `needs:` entrou, mas segue sem resposta.

## Onde aprofundar

[0023](0023-datadog-como-codigo.md) para o princípio de SaaS como código · [0027](0027-ciclo-de-vida-do-stage-datadog.md) para o ciclo de vida dos stages de SaaS · [0032](0032-triagem-por-sondas-e-report-no-slack.md) para o paralelismo entre notificar e agir · [`variaveis-e-segredos.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/docs/variaveis-e-segredos.md) para o que vai em cada secret
