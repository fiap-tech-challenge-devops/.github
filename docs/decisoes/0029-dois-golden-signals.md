# 0029 — Monitorar latência e taxa de erro; tráfego e saturação ficam como lacuna

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 16/10/2026 · **Fase:** 4

## Contexto

O enunciado pede **um** alerta, e exemplifica com a taxa de 5xx do `auth-service` acima de 5%. Um monitor atenderia. O 5% é ilustração, não requisito — ver [0034](0034-escada-de-severidade-e-espera-antes-de-remediar.md), onde ele virou o patamar de aviso.

Mas um alerta sozinho não diz nada sobre o vizinho. Quando o `evaluation` começa a errar, a primeira pergunta é se o problema é dele ou de quem ele chama — e sem monitor nos outros serviços não há como responder sem abrir o painel e investigar à mão.

Os **quatro golden signals** do livro de SRE do Google são latência, tráfego, erros e saturação. Cobrir os quatro seria o enquadramento canônico.

## Decisão

**Latência e taxa de erro, nos quatro serviços HTTP.** Oito monitores, de dois recursos com `for_each`.

**Tráfego e saturação ficam de fora**, e isso é escolha registrada, não omissão.

## Por que só dois

**Tráfego não tem linha de base.** O alerta útil de tráfego é a *queda* — o serviço parou de ser chamado, o que taxa de erro nunca enxerga, porque sem requisição não há erro. Mas o ambiente recebia **28 requisições por semana** quando os monitores foram criados. Um monitor de queda sobre isso ou dispara o tempo todo ou não significa nada.

Existe solução — um `CronJob` gerando tráfego sintético contínuo —, e ela melhoraria também os outros seis, que hoje vivem num sistema quase silencioso. Ficou fora por escopo.

**Saturação não tem métrica.** A conta do Datadog recebe **apenas APM e logs**: não há Agent no cluster, e o receiver `prometheus` do Collector está em `null`. Logo, nada de `kubernetes.*`, nada de CPU ou memória de pod, nada de conexões de banco ou profundidade de fila.

Destravar exigiria uma de três: a integração AWS do Datadog, que traz métricas do CloudWatch; o Datadog Agent no cluster, que duplicaria o papel do Collector; ou esperar o `kube-prometheus-stack` da rodada 2 e encaminhar pelo Collector. Nenhuma é cara, e nenhuma é trivial.

## Consequências

- **O `analytics-service` fica sem monitor.** Ele é consumidor de SQS escalado a zero pelo KEDA e não tem span `http.server.request`. O sinal certo para ele seria profundidade de fila — que é saturação, justamente o que falta. Fica dependente da mesma decisão
- **Com um erro em 28 requisições, a taxa é 100%.** Os monitores são sensíveis a evento isolado enquanto o tráfego for esparso. É consequência do ambiente, não da configuração
- Todos têm `notify_no_data = false`: num ambiente destruído a maior parte do tempo, ausência de dado é o estado normal, não incidente
- A cobertura em todos os serviços é o que torna legível a **falha em cascata**: um serviço estrangulado aparece como latência alta nele e erro no chamador. Com monitor em um só, essa assinatura seria invisível

## Duas armadilhas que custaram caro

Os monitores de latência nasceram mudos, por dois erros que **falham do mesmo jeito: o monitor é criado, fica verde e nunca dispara.**

**O nome.** `trace.http.server.request.duration` pertence ao namespace antigo, que a UI marca como depreciado e que não tem dado. A forma atual não tem sufixo, e o percentil vira prefixo: `p95:trace.http.server.request`.

**A unidade.** A métrica é distribuição em **segundos**, não nanossegundos. O limiar de 500ms tinha virado `500000000` em vez de `0.5` — nove ordens de grandeza. Não dispararia nem com o sistema parado.

A lição é operacional e vale mais que as duas correções: **sobre a conta do Datadog, perguntar à conta.** O nome da operação `http.server.request` foi descoberto na página de APM e acertou de primeira; a métrica e a unidade foram deduzidas de documentação genérica e erraram as duas. O autocomplete do editor de monitor mostra nome, tipo e unidade — e teria evitado os dois.

## Onde aprofundar

[`togglemaster-iac/datadog/monitors.tf`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/datadog/monitors.tf) e [`scripts/demo/`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/tree/main/scripts/demo)
