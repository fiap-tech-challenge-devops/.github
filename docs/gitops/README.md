# GitOps — como as coisas chegam ao cluster

O Argo CD observa o [`togglemaster-gitops`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops) e sincroniza o cluster com o que está lá. Nada é aplicado com `kubectl` manual.

Este domínio trata de **como** as coisas chegam. O que elas fazem depois de chegar está em [`k8s/`](../k8s/).

## A estrutura do repositório

```
applications/     Applications do Argo CD — planas, sem recursão
apps/             um values-prod.yaml por microsserviço
charts/base/      chart único, parametrizado, servindo os cinco serviços
platform/         componentes de plataforma, um chart por componente
```

**Um chart, cinco values.** Os cinco microsserviços têm o mesmo formato de deployment; muda imagem, porta, variáveis e política de escala. Um chart parametrizado evita cinco cópias que divergem com o tempo.

**`apps/` é o que a esteira altera.** O CD só muda a tag da imagem. O commit é o registro auditável do que foi promovido, quando e por qual build.

## O fluxo de deploy

```
merge na main do microsserviço
  → CI publica a imagem no ECR
  → CD commita a nova tag em apps/<serviço>/values-prod.yaml
  → Argo CD detecta a diferença
  → sync automático
```

## Quem é dono do quê

| Dono | Componentes |
|---|---|
| Terraform (`addons/`) | metrics-server, LB Controller, External Secrets, KEDA, Karpenter, Argo CD |
| Argo CD | Os cinco microsserviços e a stack de observabilidade |

A linha é o **ciclo de vida**: controllers nascem e morrem com o cluster; aplicações mudam a cada merge.

O que quebra numa arquitetura assim não é Terraform nem GitOps — é os dois gerenciando o mesmo recurso e revertendo um ao outro a cada reconcile.

## Onde está documentado

| Documento | Assunto |
|---|---|
| [`platform/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops/blob/main/platform/README.md) | **Como acrescentar um componente de plataforma** — leia antes de criar qualquer chart |
| [`docs/desafios/03`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops/tree/main/docs/desafios) | App-of-apps e a restrição do kustomize com `valueFiles` |
| `docs/desafios/04` | Template de Ingress com `group.name` e a correção do `envFrom` |
| `docs/desafios/06` | O primeiro sync real: impasse de sync-wave no KEDA |
| `docs/desafios/07` | Bootstrap da chave de serviço, `checksum/config` e `replicas` sob autoscaler |
| `docs/desafios/08` | O Collector e como charts de terceiros entram aqui |

## Decisões que afetam este domínio

| # | Decisão |
|---|---|
| [0001](../decisoes/0001-chart-de-terceiros-como-wrapper.md) | Chart de terceiros entra como dependência de um chart nosso |
| [0002](../decisoes/0002-um-chart-por-componente.md) | Um chart e uma Application por componente |
| [0003](../decisoes/0003-observabilidade-no-gitops.md) | Stack de observabilidade aqui, não no Terraform |

## O que saber antes de mexer

**`applications/` não é recursivo.** A Application raiz lê aquele diretório sem `directory.recurse` — subpastas não seriam vistas.

**Não há kustomize no repositório.** Foi removido: ele recusava `valueFiles` fora da raiz da build.

**Os values dos microsserviços usam caminho relativo** (`../../apps/<serviço>/values-prod.yaml`), o que funciona porque chart e values moram no mesmo `source`. Charts de terceiros não têm essa propriedade — ver a decisão 0001.
