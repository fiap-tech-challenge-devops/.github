# Kubernetes — o que roda no cluster

O que existe dentro do EKS, independente de como chegou lá. Como as coisas chegam está em [`gitops/`](../gitops/).

## O cluster

Amazon EKS, com um node group fixo de baseline — um `t3.large`, `min` e `max` iguais a 1 — e o **Karpenter** provisionando o resto sob demanda, com preferência por Spot e teto de 32 vCPU.

Esse teto é a trava de custo: sem ele, um bug de autoscaling na aplicação vira uma fatura.

## Namespaces

| Namespace | O quê |
|---|---|
| `togglemaster` | Os cinco microsserviços |
| `observability` | OTel Collector, e futuramente Prometheus, Loki e Grafana |
| `argocd`, `external-secrets`, `keda`, `kube-system` | Controllers |

## Os controllers e o que cada um resolve

| Controller | Papel |
|---|---|
| **External Secrets** | Traz credenciais do Secrets Manager para dentro do cluster. Nenhum segredo em texto plano nos manifests |
| **KEDA** | Escala o `analytics-service` pela profundidade da fila SQS, de 0 a 15 réplicas |
| **Karpenter** | Provisiona nós conforme os pods pendentes |
| **AWS Load Balancer Controller** | Cria o ALB a partir dos recursos `Ingress` |
| **metrics-server** | Métricas de recurso para o HPA |

## Escala

**HPA** por CPU nos serviços HTTP. **KEDA** por fila no `analytics-service`, que escala a zero quando não há mensagem — comportamento normal, e não falha: se não há pod, é porque não há trabalho.

**Ingress:** os quatro `Ingress` são fundidos em **um único ALB** pelo `alb.ingress.kubernetes.io/group.name`, com `group.order` definindo a ordem de avaliação. As rotas são por caminho: `/validate`, `/admin`, `/flags`, `/rules`, `/evaluate`.

## Onde está documentado

| Documento | Assunto |
|---|---|
| [`togglemaster-gitops/docs/desafios/05`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops/tree/main/docs/desafios) | IRSA, Job de migration por sync-wave e escala por fila |
| `togglemaster-gitops/docs/desafios/04` | Ingress com `group.name` e as lacunas do chart |
| [`togglemaster-platform-legacy/docs/desafios/02`](https://github.com/fiap-tech-challenge-devops/togglemaster-platform-legacy/tree/main/docs/desafios) | A migração do local para a nuvem, do teto de pods do Free Tier à gestão de segredos |

## O que saber antes de mexer

**Load balancers e nós do Karpenter não estão no `tfstate`.** Quem os cria são controllers rodando dentro do cluster. Se sobreviverem a um destroy, ficam órfãos e seguram a VPC — é por isso que a esteira de destroy limpa o cluster **antes** de destruir a infraestrutura, e o Argo CD sai primeiro.

**O EBS CSI driver está desligado.** Nenhum PersistentVolumeClaim é atendido hoje.

**Capacidade é apertada.** Dos `1930m` alocáveis do nó de baseline, cerca de `1550m` já estão reservados. Qualquer componente novo precisa de `resources.requests` declarado, ou o Karpenter dimensiona mal.
