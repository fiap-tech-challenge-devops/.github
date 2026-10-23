# 0032 — O Datadog notifica, a Action diagnostica e reporta

**Status:** aceita · **Domínio:** Observabilidade · CI/CD · **Data:** 22/10/2026 · **Fase:** 4

## Contexto

A [0030](0030-self-healing-em-github-action.md) decidiu que a remediação roda numa GitHub Action e deixou **as salvaguardas** abertas. A [0031](0031-self-healing-mora-no-iac.md) colocou o workflow no `togglemaster-iac`. Falta o desenho: como a automação garante que está consertando a coisa certa, e por onde o resultado aparece.

O problema é um desencontro entre o gatilho e a ação. O monitor que dispara é `[prod] evaluation-service — taxa de erro`, **genérico de propósito** ([0029](0029-dois-golden-signals.md)): ele acende para 5xx de qualquer causa — banco fora, dependência fora, OOM, nó spot reclamado, deploy ruim. Mas a remediação é cirúrgica: reverter version stage de um segredo. Executá-la porque o RDS caiu não quebra nada, mas mexe num segredo sem motivo e suja a trilha de auditoria.

Validado em 22/10, com o ambiente vivo na falha: o erro é `flag-service retornou status 401`, 401 **de saída** do `evaluation-service`. O monitor do `flag-service` fica verde, porque 4xx não marca span de servidor como erro — só o do `evaluation-service` dispara. A assinatura prevista no [roteiro de incidente](../observabilidade/roteiro-de-incidente.md) se confirmou.

## Decisão

### Confirmar que a falha ainda existe, antes de qualquer coisa

A Action não confia no alerta: ela reproduz. `GET /evaluate` com uma flag que existe, e só segue se vier `502`.

Isso não é zelo — é a salvaguarda que mais importa. O monitor tem janela de 5 minutos e `evaluation_delay` de 60s; somando a fila e o boot do runner, passam minutos entre a falha e a execução. Se nesse intervalo o problema passou, remediar é agir sobre um sistema saudável a partir de um alerta vencido. `200` aqui significa **relata e sai**.

### O monitor genérico é porta de entrada de uma triagem

A Action não assume a causa. Ela roda sondas ordenadas, e **uma única chamada HTTP distingue cinco causas** — descoberta ao ler o `require_auth` do `flag-service`, que devolve código diferente por motivo:

`GET /flags/<nome-inexistente>` com a key do `AWSCURRENT`:

| Código | O que significa | Ação |
|---|---|---|
| `401` · `403` | a chave enviada não é válida | **remedia** — reverte a rotação |
| `404` | autenticação aprovada **e** banco do `flag-service` respondeu | credencial boa, segue sondando |
| `500` | autenticação aprovada, banco do `flag-service` com erro | reporta |
| `503` | `auth-service` inalcançável | reporta |
| `504` | `auth-service` lento — timeout de 3s | reporta |

O nome inexistente é deliberado: a resposta saudável é `404`, não `200`. E ela **ainda exercita o banco**, porque o `SELECT` roda e não encontra — então `500` continua distinguível de `404` sem depender de nenhuma flag específica existir.

A sonda pergunta o que importa — *"a chave que está no `AWSCURRENT` agora funciona?"* — por comportamento, não por texto de log.

Duas sondas de cluster completam o quadro, porque a chamada HTTP bate no `flag-service` e **o monitor que dispara é do `evaluation-service`**: se o `evaluation` estiver em `CrashLoopBackOff` ou `OOMKilled` com o `flag-service` saudável, a sonda HTTP devolve `404` e não diria nada. Então: `kubectl get pods` nos serviços do fluxo, e `kubectl get nodes` mais eventos de nó. Ambas diagnosticam e reportam.

### O que a remediação toca — e o que parecia que ela precisaria tocar

O segredo `togglemaster/app/evaluation` alimenta **dois** ExternalSecrets: o `evaluation-service-app` e o `auth-service`. Isso sugeria que a remediação tivesse de reciclar os dois lados.

Não precisa. O `auth-service` valida a chave contra a tabela `api_keys` do banco dele — `SELECT id FROM api_keys WHERE key_hash = $1` —, não contra variável de ambiente. A verdade sobre *qual chave é válida* mora no banco do `auth`; o segredo guarda apenas a chave que o `evaluation` **envia**. Uma rotação ruim quebra a correspondência entre as duas, e reverter o version stage restaura a chave cujo hash o banco conhece.

Medido em 22/10 com o ambiente na falha: `AWSPREVIOUS` tem 55 caracteres (a chave gerada pelo Terraform, que está no banco) e `AWSCURRENT` tem 24 (o valor do ensaio). Os dois Secrets do cluster já carregavam o valor do ensaio — o ESO sincronizou ambos —, o que confirma que a inconsistência não era de propagação.

Então: `force-sync` nos dois ExternalSecrets, para não deixar divergência latente, mas **`delete pod` só no `evaluation-service`**, que é onde a variável é consumida. Raio de ação menor, e `delete pod` em vez de `rollout restart` porque o `selfHeal` do Argo CD trataria o restart como drift.

### Três regras que mantêm isso seguro conforme cresce

**Sonda é só leitura**, sem exceção. É o que permite rodar todas em qualquer alerta sem pensar duas vezes.

**Remedia na primeira que bate; reporta todas.** Duas causas coexistem com frequência — nó spot reclamado e pod não-pronto são o mesmo incidente por dois ângulos. Empilhar remediações num sistema já instável piora. Ordem da mais específica para a mais genérica.

**A verificação reusa a sonda que bateu.** Se ela ainda bate depois da remediação, escala em vez de tentar de novo.

### O Datadog notifica; a Action age e reporta

O monitor dispara **em paralelo** o ChatOps e o webhook. A Action, ao terminar, posta o resultado no mesmo canal. O fluxo no Slack:

```
18:42  🔴 [prod] evaluation-service — taxa de erro acima de 5%
18:45  🔧 diagnóstico: credencial inválida no AWSCURRENT → revertida, 2 pods reciclados
18:47  ✅ [prod] evaluation-service — recuperado
```

A primeira e a terceira são do Datadog; a segunda é da Action. **Duas delas vêm de sistemas que não se conhecem** — a narrativa emerge sem ninguém orquestrar.

A tabela completa das sondas vai no **Job Summary** (`$GITHUB_STEP_SUMMARY`), não no Slack: cinco linhas num canal é ruído, e quem está de plantão quer um veredito e um link. O Job Summary é também o artefato de evidência que a 0030 previu — markdown renderizado e carimbado, sem montagem.

### O filtro de transição, e o disjuntor

**Primeiro passo da Action, antes de qualquer sonda:** sair se `$ALERT_TRANSITION` não for `Triggered`. O webhook também dispara em `Recovered`, `Re-Triggered`, `Renotify`, `Warn` e `No Data` — sem o filtro, a automação reverteria um segredo **no momento em que o monitor recupera**, mexendo num sistema que acabou de voltar ao normal.

**O disjuntor conta tentativas por `$ALERT_CYCLE_KEY`**, a chave do ciclo do alerta, consultando o histórico de runs do próprio GitHub. Duas tentativas por incidente; na terceira, só reporta. Contar por ciclo diz o que se quer dizer — *"duas tentativas para este incidente"* — em vez de uma janela de tempo arbitrária.

## Alternativas descartadas

**Monitor de log dedicado como gatilho**, disparando só no padrão `status 401`, com a Action burra. Elegante em teoria — *tornar o sinal específico para que a remediação possa ser simples* —, mas acopla a automação a uma **string de log**: mudar a mensagem de erro faz a remediação parar em silêncio. A sonda pergunta por comportamento, não por texto.

**A Action acionando o PagerDuty**, com política condicional: remediou → só Slack; falhou ou nenhuma sonda bateu → acorda alguém. Descartada por colocar um **ponto único de falha no caminho mais crítico** — PAT expirado, runner na fila ou erro de bash e o incidente passa em silêncio. Com o Datadog notificando, isso não depende da Action rodar. E tira do shell script a lógica mais frágil da proposta.

**Contador do disjuntor em SSM ou DynamoDB.** Morre no destroy noturno e, pior, faz a automação depender de infraestrutura que ela mesma recupera — o princípio registrado na [0030](0030-self-healing-em-github-action.md).

**Três remediações desde já** — credencial, pod e RDS. Mais superfície coberta, mas três caminhos de escrita para testar, e só o da credencial é ensaiável sem atrapalhar a demonstração: o `start-db-instance` leva minutos. Uma remediação completa de ponta a ponta vale mais que três pela metade.

**Thread no Slack**, pendurando a mensagem da Action sob a do monitor. Impraticável: a Action não tem como saber o `ts` da mensagem que o Datadog postou. As duas vão para o mesmo canal e a da Action nomeia o monitor.

## Consequências

- **`repository_dispatch` sempre executa a versão do branch padrão.** Não existe disparar o workflow de um branch para testar: enquanto ele não estiver na `main`, o webhook não acha nada. O ensaio antes do merge é por `workflow_dispatch`, que é o motivo de ele existir no gatilho — com um input `remediar` desmarcado por padrão, para o primeiro disparo manual só diagnosticar
- **O `client_payload` do `repository_dispatch` define o que a Action sabe.** Com 8 monitores e 5 serviços, ele precisa levar ao menos transição, escopo, título e link — é Terraform no stage `datadog`, barato de corrigir depois
- **Metade da tabela diagnostica sem consertar**, e isso é proposital. Uma Action que roda cinco sondas e conclui *"é nó spot reclamado, o Karpenter está resolvendo, nada a fazer"* é triagem automatizada — o que um SRE faz nos dois primeiros minutos. Ser explícita sobre onde a automação para é mais defensável que fingir cobertura
- A sonda da credencial depende do ALB **público**; o runner está fora da VPC. Vale para as cinco sondas: nenhuma pode exigir estar dentro da rede
- **O ChatOps do monitor depende do OAuth do Datadog no Slack** ([0028](0028-slack-para-chatops.md)), travado em admin do workspace. O report da Action **não** depende dele: é um incoming webhook, caminho independente. A camada do Job Summary não depende de conta externa nenhuma e pode ser construída já

## O que esta decisão não resolve

**O PagerDuty.** Fica fora por escolha — o desenho acima não o menciona em nenhum ponto. Quando entrar, a pergunta aberta é se o Datadog o aciona pela integração padrão e o incidente se resolve sozinho na recuperação do monitor, ou se há motivo para a Action tocá-lo. A primeira hipótese é o comportamento documentado da integração e precisa de confirmação com a conta na mão, não de adivinhação.

**As sondas sem remediação.** Pod, RDS, nó e dependência ficam diagnosticando. Promover qualquer uma a remediação é decisão própria, e o critério é se dá para ensaiar a falha sem quebrar a demonstração.

## Onde aprofundar

[0030](0030-self-healing-em-github-action.md) para o porquê da Action · [0031](0031-self-healing-mora-no-iac.md) para onde ela mora · [0029](0029-dois-golden-signals.md) para por que o monitor é genérico · [roteiro de incidente](../observabilidade/roteiro-de-incidente.md) para o ensaio da falha
