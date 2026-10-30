# 0035 — A Action fecha o incidente no PagerDuty, mas não é disparada por ele

**Status:** aceita · **Domínio:** Observabilidade · CI/CD · **Validação:** não validada · **Data:** 30/10/2026 · **Fase:** 4

## Contexto

A pergunta que abriu isto foi outra: **o webhook do self-healing não poderia ser disparado pelo PagerDuty, em vez de direto pelo Datadog?**

É uma boa pergunta, e tem dois argumentos reais a favor. O enunciado exige **duas fontes de alerta** — a stack opensource com Grafana e um APM comercial —, e um funil evitaria configurar webhook em dois lugares. E o PagerDuty **deduplica alertas em incidentes nativamente**, que é uma versão pronta do disjuntor que a [0032](0032-triagem-por-sondas-e-report-no-slack.md) construiu à mão contando runs pela API do Actions.

A investigação achou um impedimento e um argumento mais forte contra.

## O impedimento técnico

O `repository_dispatch` do GitHub exige um corpo com forma específica — `event_type` no nível de cima, mais `client_payload`. O webhook do Datadog permite **moldar o corpo inteiro**, e é por isso que ele chama o GitHub direto.

O webhook V3 do PagerDuty aceita **cabeçalhos customizados, mas o corpo é o schema dele**, aninhado em `{"event": {"event_type": ..., "data": {...}}}`. O GitHub recusaria com 422.

Fazer funcionar exigiria uma das duas: **Automation Actions ou Incident Workflows** do PagerDuty, que são de tier pago e a conta é gratuita; ou **um adaptador no meio** — Lambda com API Gateway —, que é exatamente o que a [0030](0030-self-healing-em-github-action.md) descartou.

> Ressalva: a documentação do PagerDuty descreve cabeçalhos customizados e não menciona template de corpo, e a orientação oficial é transformar do lado de quem recebe. Não encontrei afirmação explícita de que não existe. Confere-se no painel em `Integrations → Generic Webhooks (v3)`.

## O argumento que decidiu

Mesmo que fosse possível, **não deveria**: funilar pelo PagerDuty **serializa dois caminhos que a [0032](0032-triagem-por-sondas-e-report-no-slack.md) fez paralelos de propósito**.

Hoje o monitor dispara e os três destinos saem juntos — Slack, PagerDuty e webhook. Nenhum depende do outro. Com o PagerDuty no meio, a remediação passa a depender do caminho de paginação: se o PagerDuty cair ou a integração quebrar, não só ninguém é avisado como **nada é consertado, e ninguém sabe que a automação não rodou**. É um modo de falha pior que qualquer um dos dois caminhos falhando sozinho.

Somando: mais um salto de latência, payload mais pobre — hoje chegam `$TAGS[service]`, `$ALERT_TRANSITION` e `$ALERT_CYCLE_KEY`, específicos e estáveis — e a Lambda de volta, em troca de um funil que ainda não é necessário, porque só existe uma fonte de alerta.

## A decisão

**O disparo continua vindo do Datadog. A volta passa a existir.**

A Action, no fim da triagem, acrescenta uma **nota no incidente** dizendo o que a automação fez, e **resolve o incidente apenas quando a verificação passou**.

Isso endereça um item que a [0033](0033-pagerduty-em-stage-proprio.md) deixou aberto: *"o fechamento automático do incidente... é o comportamento documentado da integração e ainda não foi observado aqui. Se não acontecer, cada quebra deixa incidente aberto, e em semanas o Console vira ruído"*. A Action fechando explicitamente resolve isso **sem serializar nada** — ela já rodou, o estrago já foi consertado, e fechar é o último passo.

### Resolve só com a verificação verde

Dos cinco desfechos possíveis, **um** resolve:

| Desfecho | Nota | Resolve |
|---|---|---|
| remediou e verificou | sim | **sim** |
| recuperou na janela de confirmação | sim | não |
| falha não reproduz | sim | não |
| rollback impossível — `AWSPREVIOUS` também inválido | sim | não |
| causa sem correção automática | sim | não |

Fechar um incidente que a automação não provou consertado é pior que deixá-lo aberto: **some o sinal de que alguém ainda precisa olhar**. Nos quatro casos de não-resolve a nota entra de todo jeito — é justamente aí que o plantonista mais precisa do diagnóstico.

O caso de "recuperou na espera" merece nota à parte: a condição passou, mas a Action só sondou a **credencial**, não a taxa de erro do monitor. Quem decide se o incidente acabou é o monitor, então ela anota e não fecha.

### De passagem, mede o que a 0033 não sabia

Quando não há incidente aberto, a Action consulta os resolvidos da última hora. Isso distingue duas coisas que antes eram indistinguíveis: **o Datadog resolveu sozinho** (havia incidente, e fechou) ou **nenhum incidente foi aberto**. O passo é a correção e o experimento ao mesmo tempo.

## Consequências

- **Dois secrets novos, os dois opcionais:** `PAGERDUTY_TOKEN` e `PAGERDUTY_FROM_EMAIL`. Faltando qualquer um, o passo se desliga e o resto do workflow segue — o mesmo padrão do `SLACK_WEBHOOK_URL`
- **O `From` é exigido pela API** do PagerDuty para criar nota e para resolver, com e-mail de um usuário real da conta. Sem ele, `400`. É por isso que são dois secrets e não um
- **O token fica fora do Terraform.** O `pagerduty_token` existe para o provider, mas uma chave criada por ele morreria no destroy noturno — e o self-healing precisa funcionar com o ambiente fora. Mesmo raciocínio da [0027](0027-ciclo-de-vida-do-stage-datadog.md). O preço é o mesmo token em dois lugares, e lembrar dos dois ao rotacionar
- **O passo é melhor esforço e nunca reprova o run.** A remediação já aconteceu antes dele; falhar aqui pintaria de vermelho um incidente que foi resolvido
- **`curl -f` é o que faz o passo honesto.** Sem ele o curl devolve `0` mesmo num 403, e todo teste de sucesso reportaria o que não houve
- **Token inválido e serviço inexistente têm mensagens diferentes.** A primeira versão dizia "serviço não encontrado" para os dois, o que mandaria procurar no lugar errado

## O que esta decisão não resolve

**O funil para duas fontes de alerta.** Quando o Grafana começar a alertar, ele precisará do seu próprio caminho até a Action. O PagerDuty continua não sendo o candidato — pelos motivos acima —, e a resposta provável é a Action aceitar um payload normalizado, com cada fonte montando o seu. Fica para quando existir a segunda fonte.

**A deduplicação nativa.** O disjuntor artesanal por `$ALERT_CYCLE_KEY` continua. Hoje não há defeito, porque só o monitor de taxa de erro do `evaluation-service` carrega o handle do webhook. Se outro monitor ganhar remediação, dois monitores da mesma falha viram dois ciclos distintos, logo dois runs concorrentes mexendo no mesmo segredo — e aí a dedup vira necessidade.

**Nada disto foi validado em execução.** O passo nunca rodou contra a API real. O que rodou foram os nove ramos contra uma API falsa.

## Onde aprofundar

[0030](0030-self-healing-em-github-action.md) para por que a automação é uma Action e não uma Lambda · [0032](0032-triagem-por-sondas-e-report-no-slack.md) para o paralelismo entre notificar e agir, que esta decisão preserva · [0033](0033-pagerduty-em-stage-proprio.md) para o item do fechamento automático que esta fecha · [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md) para a janela de confirmação que produz um dos desfechos
