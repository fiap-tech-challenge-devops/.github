# 0025 — Baseline em dois nós spot, com cinco tipos de instância

**Status:** aceita · **Domínio:** IaC · Kubernetes · **Data:** 15/10/2026 · **Fase:** 4

## Contexto

O node group de baseline era **um `t3.large` on-demand**, com `min` e `max` iguais a 1 — quem escala além disso é o Karpenter, que já provisiona `["spot", "on-demand"]`.

Duas coisas tornaram isso insuficiente ao mesmo tempo.

**O nó estava cheio.** Medido com o ambiente de pé: **1700m de CPU reservada, 88% do alocável**, com 34 pods — 11 da aplicação, 9 de `kube-system`, 7 do Argo CD, 3 do KEDA, 3 do External Secrets e o Collector. Sobravam ~230m. A rodada de Prometheus, Loki e Grafana não caberia.

**A pergunta de custo apareceu.** Trocar um on-demand por dois spot economizaria?

## Decisão

**Dois nós spot**, com `capacity_type` como variável e **cinco tipos de instância**, todos 2 vCPU e 8 GB:

```hcl
node_instance_types = ["t3.large", "t3a.large", "m5.large", "m5a.large", "m6i.large"]
node_capacity_type  = "SPOT"   # variável, com validação
desired/min/max     = 2
```

Os cinco tipos **não são decoração**: spot com um tipo só sorteia de um pool único. Com 5 tipos e 2 AZs são 10 pools, e isso praticamente elimina o único cenário em que o ambiente não volta sozinho — falta de capacidade em tudo que o node group aceita.

## Os números, medidos e não estimados

Preço on-demand da Pricing API; spot do `describe-spot-price-history`, no momento da decisão:

| Tipo | Spot $/h | vs on-demand |
|---|---|---|
| `t3a.large` | 0,0253 | −70% |
| `t3.large` | 0,0264 | −68% |
| `m5a.large` | 0,0371 | −55% |
| `m6i.large` | 0,0372 | −55% |
| `m5.large` | 0,0408 | −51% |
| **`t3.large` on-demand** | **0,0832** | — |

Depois do apply, a AWS escolheu **`t3a.large` e `t3.large`**, os dois mais baratos, um em cada AZ:

| | $/h | vCPU |
|---|---|---|
| Antes: 1 on-demand | 0,0832 | 2 |
| Agora: 2 spot | **0,0517** | **4** |

**38% mais barato, com o dobro de capacidade.**

**Mas a economia absoluta é pequena**, e isso precisa estar dito: em ~160h/mês, que é o regime real com o destroy agendado, são ~$5/mês. Em 24/7 seriam ~$23. **O destroy noturno economiza muito mais que esta decisão** — ele corta a maior parte das horas, e spot é ganho marginal em cima dele.

O valor real desta decisão é **capacidade**, não custo.

## Alternativas descartadas

**Manter 1 on-demand e deixar o Karpenter crescer.** Zero trabalho e zero risco novo, e preserva a divisão de papéis: o node group garante o piso, o Karpenter barateia e estica. Descartada porque, com o nó a 88%, qualquer pod novo fica `Pending` até o Karpenter responder — e a rodada 2 inteira dependeria disso.

**1 on-demand + 1 spot, em dois node groups.** Preservaria um piso garantido para Argo CD e controllers, e acrescentaria capacidade barata. Descartada por custo: ficaria em ~$0,113/h, **mais caro que o estado anterior**, quando a pergunta de partida era economia. Node group gerenciado aceita um `capacity_type` só, então seriam dois grupos para manter.

**Um nó spot só.** A maior economia por hora (~$0,026, −69%), sem pagar capacidade ociosa. Descartada porque não resolve o problema que motivou a mudança: continuaria com 2 vCPU, e a rodada 2 não caberia.

## Por que spot é aceitável aqui

Não por tolerância a risco, mas por um fato verificado: **o cluster não guarda estado.** Zero PVC, e o único StatefulSet é o controller do Argo CD, que não usa disco. Tudo que tem estado vive fora — RDS, ElastiCache, DynamoDB, SQS, Secrets Manager.

Então interrupção custa alguns minutos de indisponibilidade e **nada além**. A sequência é automática: aviso de 2 minutos, o node group drena o nó, o ASG pede reposição, os pods reagendam. *Capacity Rebalancing* vem ligado por padrão em node group spot, e troca proativamente instâncias com risco elevado antes do aviso.

O ASG do node group é gerenciado pela AWS e **repõe independente do Karpenter** — não há o deadlock de "o Karpenter morreu e ninguém provisiona".

## Consequências

- **`capacity_type` é variável, com validação de `SPOT`/`ON_DEMAND`.** Existe para o dia da gravação do vídeo: uma interrupção no meio da demonstração de self-healing não se distingue de defeito, e justamente porque o vídeo *é* sobre resiliência. Naquele dia vira `ON_DEMAND`, e volta depois
- A família `m` sai 45 a 60% mais caro em spot que a `t3a`, o que no pior caso dá ~$5/mês a mais. Fica porque `m5`, `m5a` e `m6i` **não são burstable**: num nó a 88% de CPU reservada, exaustão de crédito do `t3` e throttling são plausíveis sob carga real
- O apply **recicla o node group**, porque `capacity_type` e `instance_types` mudam o launch template. Alguns minutos de 503 pelo ALB durante a troca
- **A resiliência ainda não foi ganha.** Medido depois do apply: os 8 pods da aplicação ficaram **todos no nó 1** (88% de CPU), com o nó 2 a 7%. O chart base tem `affinity: {}`, sem `topologySpreadConstraints`, então não há garantia de espalhamento. Perder o nó 1 hoje derruba todos os serviços — a diferença é que agora eles têm para onde ir, e recuperam em vez de ficar `Pending`. Tratar isso foi **deliberadamente postergado**
- A rodada 2 cabe: o nó 2 está praticamente livre

## Onde aprofundar

[`togglemaster-iac/infra/variables.tf`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/infra/variables.tf) e o hub de [IaC](../iac/README.md)
