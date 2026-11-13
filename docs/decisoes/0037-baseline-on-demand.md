# 0037 — O baseline inteiro em on-demand, e o risco de spot só no que escala

**Status:** aceita · **Domínio:** IaC · Kubernetes · **Validação:** não validada · **Data:** 13/11/2026 · **Fase:** 4

## Contexto

A [0025](0025-baseline-em-spot.md) pôs o baseline inteiro em spot, com cinco tipos de instância, e previu o custo de uma interrupção:

> *"Interrupção custa alguns minutos de indisponibilidade e **nada além**. A sequência é automática: aviso de 2 minutos, o node group drena o nó, o ASG pede reposição, os pods reagendam. Capacity Rebalancing vem ligado por padrão em node group spot, e troca proativamente instâncias com risco elevado **antes** do aviso."*

Em **13/11/2026** o histórico do Auto Scaling registrou isto:

```
14:50:24  Failed — UnfulfillableCapacity
14:50:46  Failed — UnfulfillableCapacity
14:51:06  Failed — UnfulfillableCapacity
14:51:27  Failed — UnfulfillableCapacity
14:52:38  Failed — UnfulfillableCapacity
14:53:49  Failed — UnfulfillableCapacity
14:55:00  Failed — UnfulfillableCapacity
14:56:12  Failed — UnfulfillableCapacity
14:58:24  Failed — UnfulfillableCapacity
15:00:36  Failed — UnfulfillableCapacity
15:02:49  Successful
```

**Doze minutos com um nó só.** No dia foram 2 terminações, 12 lançamentos falhados e 4 bem-sucedidos, e as duas janelas de `NodeShutdown` caíram no horário de uso.

## Duas causas, e só a segunda importa

**O Capacity Rebalancing não teve espaço para agir.** Ele estava ligado — a 0025 acertou nisso. Mas ele sobe o substituto *antes* de perder o nó em risco, e para isso o ASG precisa de teto acima do desejado. Com `min = desired = max = 2`, não havia nenhum, então só restava o caminho reativo.

**E o caminho reativo depende de existir capacidade spot naquele instante.** Dez vezes seguidas, não existiu. Esta é a causa de fundo, e nenhum ajuste de teto a resolve: quando não há capacidade, não há o que o ASG faça.

A primeira causa justifica um `max` maior. A segunda é a que decide a arquitetura.

## A decisão

**O baseline passa inteiro a `ON_DEMAND`. O risco de spot fica onde é barato de absorver: no que o Karpenter sobe por demanda.**

O argumento é sobre o que o baseline carrega. Ele não é capacidade elástica — nele moram Argo CD, External Secrets, KEDA, o controlador do Karpenter, o Collector, Prometheus, Grafana, Loki e os cinco microsserviços. **É a plataforma inteira, e ela não deveria ser interrompível.**

O que escala além disso é outra coisa: carga de pico, por definição mais tolerante, e que o Karpenter reagenda sem ninguém notar.

| Camada | Capacidade | Por quê |
|---|---|---|
| Baseline, 2 nós | **ON_DEMAND** | sustenta a plataforma; interrupção aqui para o ambiente |
| Karpenter, por demanda | `["spot", "on-demand"]`, inalterado | pico é tolerante, e é onde a economia de spot vale |

O `max` subiu de 2 para 3. On-demand não é recuperado, mas nó ainda morre — falha de hardware, substituição de AZ —, e com teto igual ao desejado o ASG só pode repor depois de perder. O terceiro nó existe apenas durante a troca, então **o custo em regime não muda**.

## O Karpenter fica como está

Houve a tentação de deixá-lo só em `spot`, já que o baseline agora cobre a estabilidade. Foi descartado por dois motivos.

**Não economizaria nada a mais.** O Karpenter já escolhe pelo preço do que couber, então ele já pega spot quando há.

**Removeria o plano B que 13/11 mostrou ser necessário.** Naquela janela, um Karpenter spot-only não teria provisionado nada, e pods ficariam `Pending` sem causa óbvia na tela.

## O custo, medido

| | Custo/hora |
|---|---|
| `t3.large` spot, 13/11 | $0,0242 a $0,0303, conforme a AZ |
| `t3.large` on-demand | $0,0832 |

Dois nós on-demand custam **$0,106/hora a mais** que dois em spot. No ritmo atual, com o destroy noturno, isso é da ordem de **$10 por mês**; numa semana de uso intenso, perto de $25.

A premissa de custo da 0025 mudou e vale dizer: ela foi para spot **para conseguir pagar o segundo nó**. Com os créditos disponíveis e uma diferença dessa ordem, esse argumento não se sustenta mais — e a comparação honesta não é com dinheiro, é com perder uma gravação de 25 minutos pela metade.

## Alternativas descartadas

**Um lastro on-demand e um nó elástico em spot.** Foi a primeira proposta, e chegou a ser implementada: dois node groups, um de cada tipo. Garante destino estável e custa metade do aumento. Descartada por entregar menos por mais complexidade — dois node groups para manter, um nome de chave que deixava de descrever o que o grupo é, e **metade do baseline ainda interrompível**.

**Só subir o `max` para 3, mantendo spot.** Mudança de uma linha, e resolve apenas a primeira das duas causas. Quando não há capacidade spot, nenhum teto ajuda.

**Karpenter só em spot.** Descartado pelos motivos da seção acima.

**Fixar Grafana e Prometheus por `nodeAffinity`.** Deixa de fazer sentido: com o baseline inteiro on-demand, não há nó instável do qual fugir.

## Consequências

- **A mudança é só de valores padrão**, em `variables.tf`. O `main.tf` não foi tocado: `node_capacity_type` e `node_max_size` já existiam, e a válvula de escape que a 0025 criou para o dia da gravação virou o padrão de todo dia
- **O node group é atualizado no lugar.** Trocar `capacity_type` substitui os nós, mas não recria o node group nem o cluster
- **O custo sobe.** O destroy noturno continua sendo o que segura a conta, e ele não muda
- **`node_capacity_type` continua variável**, agora no sentido inverso: vira `SPOT` se em algum momento a economia importar mais que a estabilidade
- **O comentário de `node_instance_types` foi corrigido.** Ele afirmava que com dez pools *"a reposição quase sempre acha"*. Diversificar aumenta a chance de achar capacidade; não cria capacidade onde não há — e foi exatamente essa distinção que levou o baseline para on-demand

## O que esta decisão não resolve

**A causa de haver tão pouca capacidade spot.** Dez recusas seguidas, para cinco tipos em duas AZs, é mais do que azar comum. Pode ser pressão na região, pode ser restrição da conta. Não foi investigado, e a mudança torna a pergunta menos urgente sem respondê-la — ela volta se o Karpenter sofrer do mesmo.

**A terceira AZ.** A VPC tem duas subnets privadas, então são dez pools e não quinze. Mexe na topologia da rede, e é decisão de outro escopo.

**Se o Karpenter sofre do mesmo laço.** Ele também pede spot, e nada foi medido sobre o comportamento dele nestas mesmas janelas. A diferença é que ali existe o fallback para on-demand.

## Onde aprofundar

[0025](0025-baseline-em-spot.md) para por que o baseline foi para spot, e para a diversificação em cinco tipos que continua válida · [0036](0036-senha-do-grafana-por-external-secrets.md) para a outra causa da instabilidade do mesmo dia
