# Kubernetes — o que roda no cluster e como chega lá

Os dois assuntos vivem juntos aqui por um motivo prático: **neste projeto não existe Kubernetes que não chegue pelo Argo CD**. A categoria "aplicado à mão" foi eliminada na Fase 3, e separar *o que roda* de *como chega* produzia dois índices para a mesma documentação.

---

## O cluster

Amazon EKS, com um node group fixo de baseline — um `t3.large`, `min` e `max` iguais a 1 — e o **Karpenter** provisionando o resto sob demanda, com preferência por Spot e teto de 32 vCPU.

Esse teto é a trava de custo: sem ele, um bug de autoscaling na aplicação vira uma fatura.

| Namespace | O quê |
|---|---|
| `togglemaster` | Os cinco microsserviços |
| `observability` | OTel Collector, e futuramente Prometheus, Loki e Grafana |
| `argocd`, `external-secrets`, `keda`, `kube-system` | Controllers |

---

## Como as coisas chegam

O Argo CD observa o [`togglemaster-gitops`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops) e sincroniza o cluster com o que está lá. Nada é aplicado com `kubectl` manual.

```
applications/     Applications do Argo CD — planas, sem recursão
apps/             um values-prod.yaml por microsserviço
charts/base/      chart único, parametrizado, servindo os cinco serviços
platform/         componentes de plataforma, um chart por componente
```

**Um chart, cinco values.** Os cinco microsserviços têm o mesmo formato de deployment; muda imagem, porta, variáveis e política de escala. Um chart parametrizado evita cinco cópias que divergem com o tempo.

**`apps/` é o que a esteira altera.** O CD só muda a tag da imagem. O commit é o registro auditável do que foi promovido, quando e por qual build.

```
merge na main do microsserviço
  → CI publica a imagem no ECR
  → CD commita a nova tag em apps/<serviço>/values-prod.yaml
  → Argo CD detecta a diferença
  → sync automático
```

---

## Os controllers e quem é dono de cada um

| Controller | Papel | Dono |
|---|---|---|
| **External Secrets** | Traz credenciais do Secrets Manager para o cluster. Nenhum segredo em texto plano nos manifests | Terraform |
| **KEDA** | Escala o `analytics-service` pela profundidade da fila SQS, de 0 a 15 réplicas | Terraform |
| **Karpenter** | Provisiona nós conforme os pods pendentes | Terraform |
| **AWS Load Balancer Controller** | Cria o ALB a partir dos recursos `Ingress` | Terraform |
| **metrics-server** | Métricas de recurso para o HPA | Terraform |
| **Argo CD** | Sincroniza o cluster com o repositório GitOps | Terraform |
| Os cinco microsserviços | — | **Argo CD** |
| Stack de observabilidade | — | **Argo CD** |

A linha é o **ciclo de vida**: controllers nascem e morrem com o cluster; aplicações mudam a cada merge.

O que quebra numa arquitetura assim não é Terraform nem GitOps — é os dois gerenciando o mesmo recurso e revertendo um ao outro a cada reconcile.

---

## Escala e entrada

**HPA** por CPU nos serviços HTTP. **KEDA** por fila no `analytics-service`, que escala a zero quando não há mensagem — comportamento normal, e não falha: se não há pod, é porque não há trabalho.

**Ingress:** os quatro `Ingress` são fundidos em **um único ALB** pelo `alb.ingress.kubernetes.io/group.name`, com `group.order` definindo a ordem de avaliação. As rotas são por caminho: `/validate`, `/admin`, `/flags`, `/rules`, `/evaluate`.

---

## Onde está documentado

| Documento | Assunto |
|---|---|
| [`togglemaster-gitops/platform/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops/blob/main/platform/README.md) | **Como acrescentar um componente de plataforma** — leia antes de criar qualquer chart |
| [`docs/desafios/03`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops/tree/main/docs/desafios) | App-of-apps e a restrição do kustomize com `valueFiles` |
| `docs/desafios/04` | Ingress com `group.name`, correção do `envFrom` e lacunas do chart |
| `docs/desafios/05` | IRSA, Job de migration por sync-wave e escala por fila |
| `docs/desafios/06` | O primeiro sync real: impasse de sync-wave no KEDA |
| `docs/desafios/07` | Bootstrap da chave de serviço, `checksum/config` e `replicas` sob autoscaler |
| `docs/desafios/08` | O Collector e como charts de terceiros entram no repositório |
| [`togglemaster-platform-legacy/docs/desafios/02`](https://github.com/fiap-tech-challenge-devops/togglemaster-platform-legacy/tree/main/docs/desafios) | A migração do local para a nuvem, do teto de pods do Free Tier à gestão de segredos |

## Decisões que afetam este domínio

| # | Decisão |
|---|---|
| [0001](../decisoes/0001-chart-de-terceiros-como-wrapper.md) | Chart de terceiros entra como dependência de um chart nosso |
| [0002](../decisoes/0002-um-chart-por-componente.md) | Um chart e uma Application por componente de plataforma |
| [0003](../decisoes/0003-observabilidade-no-gitops.md) | Stack de observabilidade no GitOps, não no Terraform |

---

## O que saber antes de mexer

**`applications/` não é recursivo.** A Application raiz lê aquele diretório sem `directory.recurse` — subpastas não seriam vistas.

**Não há kustomize no repositório.** Foi removido: ele recusava `valueFiles` fora da raiz da build.

**Os values dos microsserviços usam caminho relativo**, o que funciona porque chart e values moram no mesmo `source`. Charts de terceiros não têm essa propriedade — ver a decisão [0001](../decisoes/0001-chart-de-terceiros-como-wrapper.md).

**Load balancers e nós do Karpenter não estão no `tfstate`.** Quem os cria são controllers rodando dentro do cluster. Se sobreviverem a um destroy, ficam órfãos e seguram a VPC — por isso a esteira de destroy limpa o cluster **antes** de destruir a infraestrutura, e o Argo CD sai primeiro.

**O EBS CSI driver está desligado.** Nenhum PersistentVolumeClaim é atendido hoje.

**Capacidade é apertada.** Dos `1930m` alocáveis do nó de baseline, cerca de `1550m` já estão reservados. Qualquer componente novo precisa de `resources.requests` declarado, ou o Karpenter dimensiona mal.
