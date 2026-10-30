# 0034 — Escada de severidade, e espera antes de remediar

**Status:** aceita · **Domínio:** Observabilidade · CI/CD · **Validação:** não validada · **Data:** 30/10/2026 · **Fase:** 4

## Contexto

Os oito monitores tinham **um** limiar cada, e o do `evaluation-service` acionava a remediação automática no mesmo instante em que notificava. Duas consequências que incomodavam por motivos diferentes.

A primeira é de operação: a remediação **reverte um segredo e recicla pods**. Disparada contra uma oscilação passageira, ela é mais destrutiva que a falha. Pior: se uma pessoa rotacionou a chave de propósito e os pods ainda não reciclaram, a automação **desfaz a mudança dela** — e, como mover `AWSCURRENT` arrasta `AWSPREVIOUS` junto, o estrago é difícil de reverter.

A segunda é de demonstração: a cadeia inteira levava 50 segundos, o que não dá tempo de mostrar a taxa de erro subindo nem de abrir um trace antes de tudo voltar ao normal.

A segunda motivou a investigação; a primeira é a que justifica a mudança. Vale registrar nessa ordem, porque o primeiro desenho proposto atendia só a segunda.

## A decisão, em duas partes

**Dois patamares no monitor de taxa de erro.** Aviso em 5%, crítico em 10%. O aviso vai só para o Slack; o crítico pagina e **autoriza** a remediação.

**Uma janela de confirmação antes de remediar.** O workflow recebe o webhook imediatamente, roda a triagem completa, e então espera **90 segundos re-sondando a credencial** antes de agir. Se voltou a autenticar, ele se recolhe e reporta isso.

A chave é relida do Secrets Manager **a cada volta** da sonda. É essa releitura que dá a propriedade que interessa: se uma pessoa corrigiu o segredo durante a espera, a automação vê a chave nova e desiste. Um `sleep` cego não teria essa propriedade.

O tempo é um parâmetro, não uma constante — variável de repositório `SELF_HEALING_ESPERA`, com 90 como padrão. A gravação da demonstração usa um valor longo sem precisar de commit, e isso é dito em voz alta no vídeo em vez de ficar embutido como se 10 minutos fosse o valor certo para produção.

### Por que o 5% saiu do crítico

O enunciado **exemplifica** 5% — "taxa de HTTP 5xx do `auth-service` acima de 5%" —, não fixa. Durante um bom tempo este repositório tratou como regra, inclusive num comentário em `variables.tf` que dizia "o enunciado pede 5%". Não pede.

O que separa os dois patamares não é gravidade percebida, é **quem responde**. A faixa de 5% a 10% é onde vive a degradação parcial — réplica ruim, banco lento, pod com configuração velha. Nenhuma delas se conserta revertendo um segredo, então é correto que essa faixa pare numa pessoa.

O nome do monitor carrega os dois números — `taxa de erro: aviso 5%, crítico 10%` — para que o 5% do enunciado continue visível num print.

## O que esta decisão corrige da 0033

A [0033](0033-pagerduty-em-stage-proprio.md) registrou um desenho de dois níveis como *"o correto para operação real"*: nível 1 em `last_5m` para Slack e remediação, nível 2 em `last_15m` com limiar ~50% para o PagerDuty. **Aquele desenho está descartado**, por uma razão que a matemática de lá não considerou: a janela de 15 minutos leva 15 minutos para **drenar**.

Com o self-healing curando em 50 segundos, o monitor de nível 2 permaneceria em alerta por mais de dez minutos depois do problema ter acabado. O plantonista acordaria para um incidente já resolvido — exatamente o ruído que a 0033 queria evitar — e o PagerDuty receberia o `resolve` com dez minutos de atraso.

O nível de severidade que entrou no lugar vive **no mesmo monitor e na mesma janela**, roteado por estado. Recupera junto com a falha.

## Alternativas descartadas

**`renotify_interval` com os handles no `escalation_message`.** Nativo do Datadog, exato, e foi o primeiro desenho proposto: a mensagem normal levaria só o Slack; dez minutos depois, se ainda em alerta, o `escalation_message` levaria PagerDuty e webhook. Elegante, e **errado em dois pontos**.

Atrasa a página do plantonista, o que contraria a [0032](0032-triagem-por-sondas-e-report-no-slack.md) — que decidiu notificar **em paralelo** à remediação, e estava certa. Em produção, atrasar o conserto é defensável; atrasar o aviso de que o serviço está 100% quebrado não é. Quem decide se espera a automação é a pessoa, com a informação na mão.

E os dez minutos custavam caro: se o MTTR podia ser 50 segundos, escolher 12 minutos doa onze minutos de indisponibilidade total por incidente — um quarto de um orçamento de erro mensal de 99,9% num único evento que o sistema sabia resolver sozinho. O ponto da remediação automática é ganhar do tempo de resposta humano; atrasada até ele, sobra a complexidade sem o benefício.

**`evaluation_delay = 660` no monitor.** Desloca a avaliação dez minutos para o passado e faz o alerta disparar dez minutos depois — direto, e uma linha. Descartada porque o campo existe para compensar atraso de ingestão, atrasa a recuperação na mesma medida, e **faz o monitor mentir sobre quando o problema começou**: o MTTD registrado passaria a ser 12 minutos em vez de 2.

**Warning em 5% e crítico em 10% como fonte do atraso**, que era a formulação original da ideia. Não funciona: os dois limiares são avaliados na mesma query, na mesma janela, no mesmo instante — o Datadog não tem o `for:` do Prometheus, e a única noção de duração que ele tem é o tamanho da janela.

Pior, neste incidente os dois patamares ficam a **quinze segundos** de distância. Com tudo falhando depois de ~30s (o tempo de o cache das flags quentes expirar), a razão sobre `last_5m` cresce como `(t − 0,5min) / 5min`: cruza 5% em ~45s e 10% em ~60s. Avaliando a cada minuto, o monitor pula de OK direto para alerta e o estado de aviso talvez nunca seja observado. A escada de severidade continua valendo — mas pelo que ela faz pela operação, não por ritmo.

## Consequências

- **O MTTR sobe de ~50s para ~2min20** quando a falha é real: 90s de confirmação mais os 50s da cadeia. É o preço de não remediar o que não precisava, e é a troca explícita desta decisão
- **O handle do webhook foi para dentro de `{{#is_alert}}`.** O aviso de 5% não alcança a remediação. O filtro de transição no porteiro do workflow **fica**: ele é a única defesa se alguém editar a mensagem pela UI
- **O `@pagerduty` reaparece em toda saída do crítico** — `{{#is_recovery}}` e `{{#is_alert_to_warning}}`. Com todos os handles dentro de blocos condicionais, a recuperação deixaria de notificar ninguém, e o `resolve` automático que a 0033 listou como não observado dependeria de comportamento implícito. São **duas** saídas e não uma: na descida a razão drena pela faixa de aviso antes de chegar a zero, então `alert → warn → OK` é a transição comum, e cobrir só `is_recovery` deixaria o incidente aberto enquanto a janela estivesse parada na faixa de aviso
- **O Slack ficou fora dos blocos**, notificando em toda transição. O ChatOps quer ver subir e recuperar
- **Os quatro monitores de latência seguem com um limiar só.** Sem escada ali: não há remediação automática ligada a eles, então o segundo patamar não teria para onde rotear
- **Um caminho novo no relatório e no Slack:** *"recuperou na janela de confirmação"*. É o caso em que a automação decide não agir, e ele precisa aparecer — automação silenciosa que se recolhe é indistinguível de automação quebrada
- **A espera não é sondagem de disponibilidade.** Ela re-sonda a **credencial** (`GET /flags/<inexistente>` com a chave do `AWSCURRENT`), que é determinística. O `/evaluate` responderia 200 por cache mesmo com a chave quebrada

## O que esta decisão não resolve

**O aviso antes de agir, com janela de aborto.** É o que de fato protege contra atropelar uma mudança deliberada: anunciar no Slack *"vou reverter o segredo em 60s"* e aceitar um `abort`. A espera atual protege por acidente — só se a pessoa terminar o conserto dentro dos 90 segundos. O desenho completo exige um canal de volta que o webhook de entrada não tem.

**Não remediar durante deploy em andamento.** Uma consulta à API do Actions resolveria; não entrou nesta rodada.

**O tier de aviso vai piscar em tráfego esparso.** Com `require_full_window = false` e denominador pequeno, 1 erro em 12 requisições já são 8,3%. Na demonstração o gerador roda a 1 req/s e a janela tem ~300 requisições, então não aparece. Em produção de madrugada, aparece.

**Nada disto foi validado em execução.** A cadeia com a espera nunca rodou ponta a ponta.

## Onde aprofundar

[0029](0029-dois-golden-signals.md) para por que só dois sinais · [0030](0030-self-healing-em-github-action.md) para onde a automação executa e os 50s medidos · [0032](0032-triagem-por-sondas-e-report-no-slack.md) para notificar e agir em paralelo · [0033](0033-pagerduty-em-stage-proprio.md) para o desenho de dois níveis que esta decisão substitui
